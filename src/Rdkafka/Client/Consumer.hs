{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}
{-# language NumericUnderscores #-}
{-# language TypeApplications #-}

module Rdkafka.Client.Consumer
  ( subscribe
  , subscribePartition
  , subscription
  , assignment
  , poll
  , pollMany
  , close
  , commit
    -- * Watermarks
  , queryPartitionWatermarks
    -- * Modify Offsets
  , offsetsStore
  , seekPartitions
    -- * Retreive message headers
  , messageHeaders
  , headerGetLast
  ) where

import Control.Exception (toException)
import Control.Monad.ST.Run (runPrimArrayST)
import Data.Bytes (Bytes)
import Data.Functor (($>))
import Data.Int (Int64)
import Data.Primitive (PrimArray)
import Data.Word (Word64)
import Foreign.C.Types (CChar,CSize)
import Data.Void (Void)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Ptr (Ptr,FunPtr,nullPtr)
import GHC.Clock (getMonotonicTimeNSec)
import GHC.Exts (raiseIO#)
import GHC.IO (IO(IO))
import Rdkafka.Client.Types (Consumer(Consumer))
import Rdkafka.Types (ResponseError,Message,Partition,OffsetCommitCallback,Watermarks(..))
import Rdkafka.Types (TopicPartitionList,Headers)

import qualified Rdkafka as X
import qualified Rdkafka.Constant.ResponseError as ResponseError
import qualified Rdkafka.Constant.Partition as Partition
import qualified Rdkafka.Struct.Message as Message
import qualified Rdkafka.Struct.TopicPartition as TopicPartition
import qualified Data.Primitive as PM
import qualified Data.Primitive.Ptr as PM

-- | Subscribe to a single topic on partition @RD_KAFKA_PARTITION_UA@.
subscribe ::
     Consumer
  -> ManagedCString -- ^ Topic name
  -> IO (Either ResponseError ())
subscribe !c !t = subscribePartition c t Partition.Unassigned

-- | Get the list of subscriptions. The caller must delete the topic
-- partition list with 'topicPartitionListDestroy' after using it.
--
-- Consider using 'assignment' instead of this.
subscription ::
     Consumer -- ^ Kafka handle
  -> IO (Either ResponseError (Ptr TopicPartitionList))
subscription (Consumer h) = do
  buf <- PM.newPinnedPrimArray 1
  PM.writePrimArray buf 0 (nullPtr :: Ptr TopicPartitionList)
  e <- X.subscription h (PM.mutablePrimArrayContents buf)
  r <- PM.readPrimArray buf 0
  case e of
    ResponseError.NoError -> pure (Right r)
    _ -> pure (Left e)

-- | Get the list of assignments. The caller must delete the topic
-- partition list with 'topicPartitionListDestroy' after using it.
assignment ::
     Consumer -- ^ Kafka handle
  -> IO (Either ResponseError (Ptr TopicPartitionList))
assignment (Consumer h) = do
  buf <- PM.newPinnedPrimArray 1
  PM.writePrimArray buf 0 (nullPtr :: Ptr TopicPartitionList)
  e <- X.assignment h (PM.mutablePrimArrayContents buf)
  r <- PM.readPrimArray buf 0
  case e of
    ResponseError.NoError -> pure (Right r)
    _ -> pure (Left e)

-- | Subscribe to a single topic a specific partition.
subscribePartition ::
     Consumer
  -> ManagedCString -- ^ Topic name
  -> Partition -- ^ Partition
  -> IO (Either ResponseError ())
subscribePartition (Consumer h) !topic !p = do
  ts <- X.topicPartitionListNew 1
  _ <- X.topicPartitionListAdd ts topic p
  e <- X.subscribe h ts
  X.topicPartitionListDestroy ts
  case e of
    ResponseError.NoError -> pure (Right ())
    _ -> pure (Left e)

-- | Commit offset on broker for a single partition. The documentation for
-- librdkafka describes the offset: \"The offset should be the offset where
-- consumption will resume, i.e., the last processed offset + 1\".
--
-- This is synchronous, blocking until the commit succeeds or fails. Failures
-- should be treated as fatal.
--
-- Implementation calls @rd_kafka_commit_queue@. For this reason, a callback
-- is required. The callback is called before this function returns.
commit ::
     Consumer
  -> ManagedCString -- ^ Topic name
  -> Partition -- ^ Partition
  -> Int64 -- ^ Offset at which processing should resume
  -> FunPtr OffsetCommitCallback
  -> IO (Either ResponseError ())
commit (Consumer h) !topic !partition !offset !cb = do
  ts <- X.topicPartitionListNew 1
  t <- X.topicPartitionListAdd ts topic partition
  TopicPartition.pokeOffset t offset
  r <- X.commitQueue_ h ts nullPtr cb
  X.topicPartitionListDestroy ts
  case r of
    ResponseError.NoError -> pure (Right ())
    e -> pure (Left e)

-- | Calls @rd_kafka_consumer_poll@. Blocks until a message is available.
-- Checks the @err@ field in the message. Returns @Right@ with the message
-- if @err@ is @RD_KAFKA_RESP_ERR_NO_ERROR@. Otherwise, returns the error
-- and destroys the message.
--
-- The caller must destroy the resulting messages with @messageDestroy@.
poll :: Consumer -> IO (Either ResponseError (Ptr Message))
poll (Consumer p) = go where
  go = do
    m <- X.consumerPoll p 1000
    if m == nullPtr
      then go
      else Message.peekError m >>= \case
        ResponseError.NoError -> pure (Right m)
        e -> do
          X.messageDestroy m
          pure (Left e)

-- | Calls @rd_kafka_consumer_poll@ in a loop. If any of the calls return
-- a fatal error message, this discards any accumulated messages and returns
-- the error message. This always blocks until receiving at least one message.
-- After that, this keeps going until either (A) the maximum number
-- of messages has been received or (B) at least one second has elapsed
-- since the start of this function. This specification guarantees that
-- this function only blocks for more than one second if there are no
-- enqueued messages.
--
-- The caller must destroy all of the resulting messages with @messageDestroy@.
--
-- Note: due to implementation details, this might only accumulate messages for
-- 999ms rather than a full second.
pollMany ::
     Consumer
  -> Int -- ^ Maximum number of messages to receive
  -> IO (Either ResponseError (PrimArray (Ptr Message)))
pollMany c@(Consumer !p) !maxMsgs = do
  !start <- fromIntegral @Word64 @Int64 <$> getMonotonicTimeNSec
  poll c >>= \case
    Left err -> pure (Left err)
    Right msg0 -> do
      !now0 <- fromIntegral @Word64 @Int64 <$> getMonotonicTimeNSec
      let !end = start + 1000000000
      let !nanosRemaining0 = end - now0
      if nanosRemaining0 < 1000000 || maxMsgs < 2
        then pure $! Right $! inlineSingletonPrimArray msg0
        else do
          !dst <- PM.newPrimArray maxMsgs
          PM.writePrimArray dst 0 msg0
          let finish !len = do
                PM.shrinkMutablePrimArray dst len
                dst' <- PM.unsafeFreezePrimArray dst
                pure (Right dst')
          let go !ix !nanosRemaining = if ix < maxMsgs && nanosRemaining >= 1000000
                then do
                  m <- X.consumerPoll p
                    (fromIntegral @Int64 @Int (div nanosRemaining 1000000))
                  if m == nullPtr
                    then finish ix
                    else Message.peekError m >>= \case
                      ResponseError.NoError -> do
                        PM.writePrimArray dst ix m
                        !now <- fromIntegral @Word64 @Int64 <$> getMonotonicTimeNSec
                        go (ix + 1) (end - now)
                      e -> do
                        X.messageDestroy m
                        pure (Left e)
                else finish ix
          go 1 nanosRemaining0

-- | Calls @rd_kafka_consumer_close@ and @rd_kafka_destroy@. The @librdkafka@
-- specifies that @rd_kafka_consumer_close@ will
-- "block until the consumer has revoked its assignment, calling the
-- @rebalance_cb@ if it is configured, committed offsets to broker,
-- and left the consumer group." Do not use the consumer after calling
-- this function.
close :: Consumer -> IO (Either ResponseError ())
close (Consumer h) = X.consumerClose h >>= \case
  ResponseError.NoError -> X.destroy h $> Right ()
  e -> pure (Left e)

inlineSingletonPrimArray :: Ptr Message -> PrimArray (Ptr Message)
inlineSingletonPrimArray !msg = runPrimArrayST $ do
  dst <- PM.newPrimArray 1
  PM.writePrimArray dst 0 msg
  PM.unsafeFreezePrimArray dst

-- | Wait forever for watermark offsets. Technically, this could be run on
-- a producer or a consumer, but consumption seems like the only context
-- in which it makes sense to do this.
queryPartitionWatermarks ::
     Consumer
  -> ManagedCString -- ^ Topic name
  -> Partition -- ^ Partition, do not provide the unknown partition
  -> IO (Either ResponseError Watermarks)
queryPartitionWatermarks (Consumer h) !name !p = do
  buf <- PM.newPinnedPrimArray 2
  -- Should not need to initialize these since they will be
  -- overwritten, but just in case, we do anyway.
  PM.writePrimArray buf 0 (0 :: Int64)
  PM.writePrimArray buf 1 (0 :: Int64)
  let addr = PM.mutablePrimArrayContents buf
  e <- X.queryWatermarkOffsets h name p addr (PM.advancePtr addr 1) 30_000
  low <- PM.readPrimArray buf 0
  high <- PM.readPrimArray buf 1
  case e of
    ResponseError.NoError -> pure (Right Watermarks{low=low, high=high})
    _ -> pure (Left e)

-- | Calls @rd_kafka_offsets_store@. Per the librdkafka docs, this may only
-- be used when @enable.auto.offset.store@ is false.
offsetsStore ::
     Consumer
  -> Ptr TopicPartitionList
  -> IO (Either ResponseError ())
offsetsStore (Consumer h) !tpl = do
  e <- X.offsetsStore h tpl
  case e of
    ResponseError.NoError -> pure (Right ())
    _ -> pure (Left e)

-- | Calls @rd_kafka_seek_partitions@.
seekPartitions ::
     Consumer
  -> Ptr TopicPartitionList
  -> IO (Either ResponseError ())
seekPartitions (Consumer h) !tpl = do
  e <- X.seekPartitions h tpl 30_000
  case e of
    ResponseError.NoError -> pure (Right ())
    _ -> pure (Left e)

-- | Calls @rd_kafka_message_headers@. Returns @RD_KAFKA_RESP_ERR__NOENT@
-- if no headers are present.
messageHeaders ::
     Ptr Message
  -> IO (Either ResponseError (Ptr Headers))
messageHeaders m = do
  buf <- PM.newPinnedPrimArray 1
  PM.writePrimArray buf 0 (nullPtr :: Ptr Headers)
  e <- X.messageHeaders m (PM.mutablePrimArrayContents buf)
  r <- PM.readPrimArray buf 0
  case e of
    ResponseError.NoError -> pure (Right r)
    _ -> pure (Left e)

-- | Returns @RD_KAFKA_RESP_ERR__NOENT@ if no matching header found.
headerGetLast ::
     Ptr Headers
  -> Ptr CChar -- ^ Must be null-terminated
  -> IO (Either ResponseError (Ptr Void, CSize))
{-# inline headerGetLast #-}
headerGetLast !hdrs !key = do
  payload <- PM.newPinnedPrimArray 1
  PM.writePrimArray payload 0 (nullPtr :: Ptr Void)
  size <- PM.newPinnedPrimArray 1
  PM.writePrimArray size 0 (0 :: CSize)
  e <- X.headerGetLast hdrs key
    (PM.mutablePrimArrayContents payload) (PM.mutablePrimArrayContents size)
  payload' <- PM.readPrimArray payload 0
  size' <- PM.readPrimArray size 0
  case e of
    ResponseError.NoError -> pure (Right (payload', size'))
    _ -> pure (Left e)

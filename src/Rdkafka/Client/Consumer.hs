{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}

module Rdkafka.Client.Consumer
  ( subscribe
  , poll
  , close
  ) where

import Data.Functor (($>))
import Data.Bytes (Bytes)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Ptr (Ptr,nullPtr)
import Rdkafka.Client.Types (Consumer(Consumer))
import Rdkafka.Types (ResponseError,Message)
import GHC.IO (IO(IO))
import GHC.Exts (raiseIO#)
import Control.Exception (toException)

import qualified Rdkafka as X
import qualified Rdkafka.Constant.ResponseError as ResponseError
import qualified Rdkafka.Constant.Partition as Partition
import qualified Rdkafka.Struct.Message as Message

-- | Subscribe to a single topic on partition @RD_KAFKA_PARTITION_UA@.
subscribe ::
     Consumer
  -> ManagedCString -- ^ Topic name
  -> IO (Either ResponseError ())
subscribe (Consumer h) !topic = do
  ts <- X.topicPartitionListNew 1
  _ <- X.topicPartitionListAdd ts topic Partition.Unassigned
  e <- X.subscribe h ts
  X.topicPartitionListDestroy ts
  case e of
    ResponseError.NoError -> pure (Right ())
    _ -> pure (Left e)

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

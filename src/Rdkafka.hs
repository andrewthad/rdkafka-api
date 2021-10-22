{-# language BangPatterns #-}
{-# language DerivingStrategies #-}
{-# language DeriveAnyClass #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}
{-# language KindSignatures #-}
{-# language ScopedTypeVariables #-}
{-# language TypeApplications #-}
{-# language UnboxedSums #-}
{-# language UnboxedTuples #-}
{-# language UnliftedFFITypes #-}

module Rdkafka
  ( configurationNew
  , configurationDestroy
  , configurationSet
  , configurationSetLogCallback
  , configurationSetDeliveryReportMessageCallback
  , topicPartitionListNew
  , topicPartitionListAdd
  , topicPartitionListDestroy
  , topicName
  , pollSetConsumer
  , new
  , flush
  , destroy
  , consumerClose
  , subscribe
  , messageDestroy
  , newTopicNew
  , newTopicDestroy
  , eventDestroy
  , createTopic
  , eventType
  , version
  , versionString
  , versionByteArray
  , versionByteString
    -- * Poll
  , consumerPoll
  , consumerPollNonblocking
  , poll
  , pollNonblocking
  , queuePoll
    -- * Produce
  , produceBytes
  , produceBytesBlocking
  , produceBytesOpaque
    -- * Wrapper
  , wrapDeliveryReportMessageCallback
  , wrapLogCallback
    -- * Auxiliary Functions
    -- | These functions are not part of @librdkafka@, but they are
    -- useful when using this library.
  , destroyMessageOpaque
  , destroyMessageOpaque_
  , finalizeErrorBuffer
  ) where

import Control.Exception (Exception,toException)
import Data.ByteString (ByteString)
import Data.Bytes.Types (Bytes(Bytes))
import Data.Kind (Type)
import Data.Primitive (ByteArray(ByteArray),MutableByteArray(MutableByteArray))
import Data.Word (Word8,Word32)
import Foreign.C.String.Managed (ManagedCString(ManagedCString))
import Foreign.C.Types (CInt,CSize,CChar)
import Foreign.Ptr (Ptr,FunPtr,castPtr,nullPtr)
import GHC.Exts (Any,ByteArray#,MutableByteArray#,RealWorld,Int(I#))
import GHC.IO (IO(IO))
import GHC.Stable (StablePtr(StablePtr),freeStablePtr,castStablePtrToPtr,newStablePtr)
import GHC.Stable (castPtrToStablePtr,deRefStablePtr)
import Rdkafka.Types (Configuration,LogCallback,MessageOpaque(..))
import Rdkafka.Types (DeliveryReportMessageCallback,Partition(..))
import Rdkafka.Types (EventType)
import Rdkafka.Types (Message,NewTopic,AdminOptions,Queue,Event)
import Rdkafka.Types (ResponseError,Handle,ConfigurationResult)
import Rdkafka.Types (TopicPartitionList,TopicPartition,Topic)

import qualified Data.Bytes as Bytes
import qualified Data.ByteString.Unsafe as ByteString
import qualified Data.Primitive as PM
import qualified Foreign.C.Types
import qualified Foreign.C.String.Managed as ManagedCString
import qualified GHC.Exts as Exts
import qualified Rdkafka.Constant.ResponseError as ResponseError
import qualified Rdkafka.Types as T

-- | Create a new @rd_kafka_t@. Calls @rd_kafka_new@.
new ::
     T.Type -- ^ Consumer or producer
  -> Ptr Configuration -- ^ Configuration
  -> MutableByteArray RealWorld -- ^ Error string buffer
  -> Int -- ^ Error string size
  -> IO (Ptr Handle)
new typ conf (MutableByteArray buf) sz =
  rdKafkaNew typ conf buf (fromIntegral @Int @CSize sz)

-- | Create a new @rd_kafka_topic_partition_list_t@.
-- Calls @rd_kafka_topic_partition_list_new@.
topicPartitionListNew ::
     Int -- ^ Initial size of list
  -> IO (Ptr TopicPartitionList)
topicPartitionListNew n =
  rdKafkaTopicPartitionListNew (fromIntegral @Int @CInt n)

-- | Calls @rd_kafka_topic_partition_list_add@.
topicPartitionListAdd ::
     Ptr TopicPartitionList
  -> ManagedCString -- ^ Topic name
  -> Partition
  -> IO (Ptr TopicPartition)
topicPartitionListAdd !tpl !t !prt =
  rdKafkaTopicPartitionListAdd tpl t# prt
  where
  !(ManagedCString (ByteArray t# )) = t

-- | Calls @rd_kafka_NewTopic_new@.
newTopicNew ::
     ManagedCString -- ^ Topic name
  -> Int -- ^ Number of partitions
  -> Int -- ^ Replication factor
  -> MutableByteArray RealWorld -- ^ Error string buffer
  -> Int -- ^ Error string size
  -> IO (Ptr NewTopic)
newTopicNew !t !prts !rpl (MutableByteArray errBuf) errLen =
  rdKafkaNewTopicNew
    t#
    (fromIntegral @Int @CInt prts)
    (fromIntegral @Int @CInt rpl)
    errBuf
    (fromIntegral @Int @CSize errLen)
  where
  !(ManagedCString (ByteArray t# )) = t

-- | Calls @rd_kafka_consumer_poll@. Blocks until a message is available
-- or until the specified number of milliseconds have elapsed. Uses the
-- safe FFI.
queuePoll ::
     Ptr Queue -- ^ Kafka handle
  -> Int -- ^ Milliseconds to wait for message, @-1@ means wait indefinitely
  -> IO (Ptr Event)
queuePoll !tpl !ms =
  safeRdKafkaQueuePoll tpl (fromIntegral @Int @CInt ms)

-- | Calls @rd_kafka_flush@. Blocks until all outstanding produce
-- requests are completed. Uses the safe FFI.
flush ::
     Ptr Handle -- ^ Kafka handle
  -> Int -- ^ Milliseconds to wait for flush to complete
  -> IO ResponseError
flush !tpl !ms =
  safeRdKafkaFlush tpl (fromIntegral @Int @CInt ms)

-- | Calls @rd_kafka_version@ to produce a four-byte version integer. The
-- bytes are to be interpretted as hex @MM.mm.rr.xx@:
--
-- * @MM@ = Major
-- * @mm@ = minor
-- * @rr@ = revision
-- * @xx@ = pre-release id (0xff is the final release)
--
-- Note: @rd_kafka_version@ returns a C @int@, but this wrapper uses @Word32@,
-- which more accurately captures the intent.
version :: IO Word32
version = fmap (fromIntegral @CInt @Word32) rdKafkaVersion

-- | Variant of 'versionString' that also calls @strlen@ and copies the
-- result into managed memory. 
versionByteArray :: IO ByteArray
versionByteArray = do
  -- We use 128 because librdkafka hard codes that as the maximum possible
  -- length of a version string.
  dst@(MutableByteArray dst# ) <- PM.newByteArray 128
  n <- hsrdkCopyVersionString dst#
  shrinkMutableByteArray dst n
  PM.unsafeFreezeByteArray dst

-- | Variant of 'versionString' that calls @strlen@ and wraps up the
-- unmanaged memory backing it as a 'ByteString'.
versionByteString :: IO ByteString
versionByteString = do
  ptr <- versionString
  -- TODO: With sufficiently new versions of bytestring, use
  -- unsafePackAddress instead.
  ByteString.unsafePackCString ptr

-- | Calls @rd_kafka_consumer_poll@. Blocks until a message is available
-- or until the specified number of milliseconds have elapsed. Uses the
-- safe FFI.
--
-- This returns @NULL@ to indicate timeout.
consumerPoll ::
     Ptr Handle -- ^ Kafka handle
  -> Int -- ^ Milliseconds to wait for message, @-1@ means wait indefinitely
  -> IO (Ptr Message)
consumerPoll !tpl !ms =
  safeRdKafkaConsumerPoll tpl (fromIntegral @Int @CInt ms)

-- | Calls @rd_kafka_consumer_poll@, returning immidiately if no messages
-- are on the queue. This is more efficient that calling 'consumerPoll' with
-- the timeout set to zero since this variant uses the unsafe FFI.
consumerPollNonblocking ::
     Ptr Handle -- ^ Kafka handle
  -> IO (Ptr Message)
consumerPollNonblocking !tpl = unsafeRdKafkaConsumerPoll tpl 0

-- | Calls @rd_kafka_poll@. Blocks until a message is available
-- or until the specified number of milliseconds have elapsed. Uses the
-- safe FFI.
poll ::
     Ptr Handle -- ^ Kafka handle
  -> Int -- ^ Milliseconds to wait for message, @-1@ means wait indefinitely
  -> IO Int
poll !tpl !ms =
  fmap (fromIntegral @CInt @Int) (safeRdKafkaPoll tpl (fromIntegral @Int @CInt ms))

-- | Calls @rd_kafka_poll@, returning immidiately if no messages
-- are on the queue. This is more efficient that calling 'poll' with
-- the timeout set to zero since this variant uses the unsafe FFI.
-- Returns the number of events served.
pollNonblocking ::
     Ptr Handle -- ^ Kafka handle
  -> IO Int
pollNonblocking !tpl = fmap (fromIntegral @CInt @Int) (unsafeRdKafkaPoll tpl 0)

-- | Sets a configuration property. Calls @rd_kafka_conf_set@. If the
-- result is not @RD_KAFKA_CONF_OK@, the caller should call
-- @finalizeErrorBuffer@ and present the error message.
configurationSet ::
     Ptr Configuration
  -> ManagedCString -- ^ Name
  -> ManagedCString -- ^ Value
  -> MutableByteArray RealWorld -- ^ Error string buffer
  -> Int -- ^ Error string size
  -> IO ConfigurationResult
configurationSet !p !name !val (MutableByteArray err# ) !errSz =
  rdKafkaConfSet p name# val# err# (fromIntegral @Int @CSize errSz)
  where
  !(ManagedCString (ByteArray name# )) = name
  !(ManagedCString (ByteArray val# )) = val

-- | Calls @rd_kafka_conf_set_log_cb@. In a real application, this should
-- always be set. The default is to log everything to @stderr@, but if Haskell
-- code is also logging to @stderr@, the result might be mangled logs.
configurationSetLogCallback ::
     Ptr Configuration -- ^ Configuration
  -> FunPtr LogCallback -- ^ Callback
  -> IO ()
configurationSetLogCallback = rdKafkaConfSetLogCb

-- | Calls @rd_kafka_conf_set_dr_msg_cb@. See 'configurationSetLogCallback'.
configurationSetDeliveryReportMessageCallback ::
     Ptr Configuration -- ^ Configuration
  -> FunPtr DeliveryReportMessageCallback -- ^ Callback
  -> IO ()
configurationSetDeliveryReportMessageCallback =
  rdKafkaConfSetDeliveryReportMessageCallback

-- Create a StablePtr that keeps a pinned byte array live for the
-- duration of message delivery. If the produce succeeds, the StablePtr
-- goes into the @_private@ field of the @rd_kafka_message_t@. If
-- the produce fails (any status other than @RD_KAFKA_RESP_ERR_NO_ERROR@),
-- the StablePtr is destroyed immidiately. 
anchorPinnedAndPushNonblocking ::
     Ptr Handle
  -> (# (# #) | Any #)
  -> ManagedCString
  -> Bytes -- precondition: payload is pinned
  -> IO ResponseError
anchorPinnedAndPushNonblocking !h extra (ManagedCString (ByteArray topic# ))
    (Bytes (ByteArray arr# ) off len) = do
  -- TODO: Use mask to prevent memory leaks
  stable <- newStablePtr $! Opaque extra arr#
  e <- pushNonblockingNoncopyingOpaque h topic# arr# off len
    (MessageOpaque (castStablePtrToPtr stable))
  case e of
    ResponseError.NoError -> pure ()
    _ -> freeStablePtr stable
  pure e

-- Variant of anchorPinnedAndPushNonblocking that blocks.
anchorPinnedAndPushBlocking ::
     Ptr Handle
  -> (# (# #) | Any #)
  -> ManagedCString -- precondition: pinned
  -> Bytes -- precondition: payload is pinned
  -> IO ResponseError
anchorPinnedAndPushBlocking !h extra (ManagedCString (ByteArray topic# ))
    (Bytes (ByteArray arr# ) off len) = do
  -- TODO: Use mask to prevent memory leaks
  stable <- newStablePtr $! OpaqueWithTopic extra arr# topic#
  e <- pushBlockingNoncopyingOpaque h topic# arr# off len
    (MessageOpaque (castStablePtrToPtr stable))
  case e of
    ResponseError.NoError -> pure ()
    _ -> freeStablePtr stable
  pure e

-- | Variant of @produceBytes@ that associates an opaque value with the
-- sent message. The opaque value can be accessed in the callback by calling
-- 'destroyMessageOpaque'.
produceBytesOpaque ::
     Ptr Handle -- ^ Handle to kakfa cluster
  -> ManagedCString -- ^ Topic name
  -> Bytes -- ^ Message
  -> Any -- ^ Opaque value for callback
  -> IO ResponseError
produceBytesOpaque !h !topic bs@(Bytes arr@(ByteArray arr# ) off len) opaque =
  case PM.isByteArrayPinned arr of
    True -> anchorPinnedAndPushNonblocking h (# | opaque #) topic bs
    False -> do
      let !(ByteArray emptyArr#) = mempty
      -- TODO: use mask to prevent memory leaks
      stable <- newStablePtr $! Opaque (# | opaque #) emptyArr#
      e <- pushNonblockingCopyingOpaque h topic# arr# off len
        (MessageOpaque (castStablePtrToPtr stable))
      case e of
        ResponseError.NoError -> pure ()
        _ -> freeStablePtr stable
      pure e
  where
  !(ManagedCString (ByteArray topic# )) = topic

-- | Push a message to the provided topic. None of the arguments need
-- to be pinned, although if the message is pinned, copying is avoided.
-- Calls @rd_kafka_producev@. This is nonblocking. If rdkafka's message
-- queue is full, this returns @RD_KAFKA_RESP_ERR__QUEUE_FULL@. See
-- 'produceBytesBlocking' for a variant that sets @RD_KAFKA_MSG_F_BLOCK@.
produceBytes ::
     Ptr Handle -- ^ Handle to kakfa cluster
  -> ManagedCString -- ^ Topic name
  -> Bytes -- ^ Message
  -> IO ResponseError
produceBytes !h !topic bs@(Bytes arr@(ByteArray arr# ) off len) =
  case PM.isByteArrayPinned arr of
    True -> anchorPinnedAndPushNonblocking h (# (# #) | #) topic bs
    False -> pushNonblockingCopyingNoOpaque h topic# arr# off len
  where
  !(ManagedCString (ByteArray topic# )) = topic

-- | Variant of 'produceBytes' that sets @RD_KAFKA_MSG_F_BLOCK@. Consequently,
-- this never returns @RD_KAFKA_RESP_ERR__QUEUE_FULL@.
--
-- This makes a pinned copy of the topic name if the topic name was
-- not already pinned.
produceBytesBlocking ::
     Ptr Handle -- ^ Handle to kakfa cluster
  -> ManagedCString -- ^ Topic name
  -> Bytes -- ^ Message
  -> IO ResponseError
produceBytesBlocking !h !topic !b0 =
  anchorPinnedAndPushBlocking h (# (# #) | #) (ManagedCString.pin topic) bs
  where
  !bs@(Bytes arr@(ByteArray arr# ) off len) = Bytes.pin b0

-- | Recover the opaque object from in a callback, dissolving the @StablePtr@
-- that had been used to protect the opaque object or the payload from garbage
-- collection. Either this or @destroyMessageOpaque_@ must be called during delivery
-- callbacks to prevent memory leaks.
--
-- The caller must use @unsafeCoerce@ to coerce the @Any@ back to the expected
-- type.
destroyMessageOpaque ::
     MessageOpaque -- ^ Must not be used after calling this function
  -> IO (Maybe Any)
destroyMessageOpaque (MessageOpaque p) = if p == nullPtr
  then pure Nothing
  else do
    let s = castPtrToStablePtr @Opaque p
    Opaque m _ <- deRefStablePtr s
    case m of
      (# (# #) | #) -> pure Nothing
      (# | a #) -> pure (Just a)

-- | Variant of 'destroyMessageOpaque' that ignores the opaque object. This is
-- useful when the caller does not make use of opaque objects. This still
-- dissolves the association between a @StablePtr@ and its target, and it
-- is important to call either this or 'destroyMessageOpaque' in every delivery
-- callback, lest the application leak memory.
destroyMessageOpaque_ :: MessageOpaque -> IO ()
destroyMessageOpaque_ (MessageOpaque p) = if p == nullPtr
  then pure ()
  else freeStablePtr (castPtrToStablePtr p)

-- | Shrink and freeze the buffer in-place, taking bytes until the first
-- @NUL@ byte is encountered. Example use:
--
-- > conf <- configurationNew
-- > errBuf <- newByteArray 512
-- > configurationSet conf "log_level" "6" errBuf 512 >>= \case
-- >   ConfigurationResult.Ok -> pure ()
-- >   _ -> do
-- >     errMsg <- finalizeErrorBuffer errBuf
-- >     myErrorLogger errMsg
finalizeErrorBuffer :: MutableByteArray RealWorld -> IO Bytes
finalizeErrorBuffer !msg = do
  len <- PM.getSizeofMutableByteArray msg
  go 0 len
  where
  go !ix !len = if ix < len
    then PM.readByteArray msg ix >>= \case
      (0 :: Word8) -> do
        shrinkMutableByteArray msg ix 
        r <- PM.unsafeFreezeByteArray msg
        pure (Bytes r 0 ix)
      _ -> go (ix + 1) len
    else die ErrorBufferMissingNulException

-- This requires unsafeCoerce, but StablePtr can hold unlifted types
-- just fine.
makeByteArrayStablePtr :: ByteArray# -> IO (StablePtr Any)
makeByteArrayStablePtr x = IO $ \s0 ->
  case Exts.makeStablePtr# (Exts.unsafeCoerce# x :: (Any :: Type)) s0 of
    (# s1, p #) -> (# s1, StablePtr p #)

die :: Exception e => e -> IO a
{-# inline die #-}
die e = IO (Exts.raiseIO# (toException e))


shrinkMutableByteArray ::
     MutableByteArray RealWorld
  -> Int -- new size
  -> IO ()
{-# INLINE shrinkMutableByteArray #-}
shrinkMutableByteArray (MutableByteArray arr#) (I# n#) = IO $ \s ->
  case Exts.shrinkMutableByteArray# arr# n# s of
    s' -> (# s', () #)

-- | Thrown if the caller attempts to finalize an error buffer that did not
-- have a @NUL@ byte in it.
data ErrorBufferMissingNulException = ErrorBufferMissingNulException
  deriving stock (Eq,Show)
  deriving anyclass (Exception)

-- Internal use only. Does not correspond to a type from @librdkafka@.
data Opaque = Opaque
  (# (# #) | Any #) -- Optionally, the opaque value for the callback
  ByteArray# -- A reference to the payload used to keep it live

-- Internal use only. Does not correspond to a type from @librdkafka@.
-- This variant of Opaque is needed for the blocking produce functions,
-- which need to be certain that they keep the topic live.
data OpaqueWithTopic = OpaqueWithTopic
  (# (# #) | Any #) -- Optionally, the opaque value for the callback
  ByteArray# -- A reference to the payload used to keep it live
  ByteArray# -- A reference to the topic name used to keep it live

foreign import ccall unsafe "hsrdk_copy_version_string"
  hsrdkCopyVersionString :: MutableByteArray# s -> IO Int

-- | Variant of @rd_kafka_CreateTopics@ that creates a single topic rather
-- than an array of them.
foreign import ccall unsafe "hsrdk_create_topic"
  createTopic ::
       Ptr Handle -- ^ Kafka handle
    -> Ptr NewTopic -- ^ Topic to create
    -> Ptr AdminOptions -- ^ Optional admin options, or @NULL@ for defaults.
    -> Ptr Queue -- ^ Queue to emit result on.
    -> IO ()

-- Blocking call, safe FFI.
foreign import ccall safe "hsrdk_push_blocking_noncopying_opaque"
  pushBlockingNoncopyingOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray#
    -> Int
    -> Int
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_noncopying_opaque"
  pushNonblockingNoncopyingOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray#
    -> Int
    -> Int
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_copying_opaque"
  pushNonblockingCopyingOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray#
    -> Int
    -> Int
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_copying_no_opaque"
  pushNonblockingCopyingNoOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray#
    -> Int
    -> Int
    -> IO ResponseError

foreign import ccall unsafe "rd_kafka_new"
  rdKafkaNew ::
       T.Type
    -> Ptr Configuration
    -> MutableByteArray# RealWorld
    -> CSize
    -> IO (Ptr Handle)

-- | Create a new @rd_kafka_conf_t@. Calls @rd_kafka_conf_new@.
foreign import ccall unsafe "rd_kafka_conf_new"
  configurationNew :: IO (Ptr Configuration)

-- | Destroys a configuration object. Calls @rd_kafka_conf_destroy@.
foreign import ccall unsafe "rd_kafka_conf_destroy"
  configurationDestroy :: Ptr Configuration -> IO ()

foreign import ccall unsafe "rd_kafka_conf_set_log_cb"
  rdKafkaConfSetLogCb :: Ptr Configuration -> FunPtr LogCallback -> IO ()

foreign import ccall unsafe "rd_kafka_conf_set_dr_msg_cb"
  rdKafkaConfSetDeliveryReportMessageCallback ::
    Ptr Configuration -> FunPtr DeliveryReportMessageCallback -> IO ()

-- | Calls @rd_kafka_poll_set_consumer@.
foreign import ccall unsafe "rd_kafka_poll_set_consumer"
  pollSetConsumer ::
       Ptr Handle -- ^ Kafka handle
    -> IO ResponseError

-- | Calls @rd_kafka_subscribe@.
foreign import ccall unsafe "rd_kafka_subscribe"
  subscribe ::
       Ptr Handle -- ^ Kafka handle
    -> Ptr TopicPartitionList -- ^ Topics
    -> IO ResponseError

-- | Calls @rd_kafka_topic_name@.
foreign import ccall unsafe "rd_kafka_topic_name"
  topicName ::
       Ptr Topic -- ^ Topic
    -> IO (Ptr CChar)

-- | Calls @rd_kafka_topic_partition_list_destroy@.
foreign import ccall unsafe "rd_kafka_topic_partition_list_destroy"
  topicPartitionListDestroy ::
       Ptr TopicPartitionList -- ^ Topics
    -> IO ()

-- | Calls @rd_kafka_consumer_close@ using the safe FFI.
foreign import ccall safe "rd_kafka_consumer_close"
  consumerClose ::
       Ptr Handle -- ^ Kafka handle
    -> IO ResponseError

-- | Calls @rd_kafka_destroy@ using the safe FFI.
-- Blocks until any in-flight messages have had callbacks called.
foreign import ccall safe "rd_kafka_destroy"
  destroy ::
       Ptr Handle -- ^ Kafka handle
    -> IO ()

-- | Calls @rd_kafka_NewTopic_destroy@.
foreign import ccall unsafe "rd_kafka_NewTopic_destroy"
  newTopicDestroy ::
       Ptr NewTopic -- ^ @NewTopic@ to free
    -> IO ()

-- | Calls @rd_kafka_event_destroy@.
foreign import ccall unsafe "rd_kafka_event_destroy"
  eventDestroy ::
       Ptr Event -- ^ @Event@ to free
    -> IO ()

-- | Calls @rd_kafka_message_destroy@.
foreign import ccall unsafe "rd_kafka_message_destroy"
  messageDestroy ::
       Ptr Message -- ^ @Event@ to free
    -> IO ()

foreign import ccall unsafe "rd_kafka_topic_partition_list_new"
  rdKafkaTopicPartitionListNew :: CInt -> IO (Ptr TopicPartitionList)

-- | Calls @rd_kafka_event_type@.
foreign import ccall unsafe "rd_kafka_event_type"
  eventType ::
       Ptr Event -- ^ Event to inspect
    -> IO EventType

foreign import ccall unsafe "rd_kafka_conf_set"
  rdKafkaConfSet ::
       Ptr Configuration
    -> ByteArray#
    -> ByteArray#
    -> MutableByteArray# RealWorld
    -> CSize
    -> IO ConfigurationResult

foreign import ccall unsafe "rd_kafka_topic_partition_list_add"
  rdKafkaTopicPartitionListAdd ::
       Ptr TopicPartitionList
    -> ByteArray#
    -> Partition
    -> IO (Ptr TopicPartition)

foreign import ccall unsafe "rd_kafka_NewTopic_new"
  rdKafkaNewTopicNew ::
       ByteArray#
    -> CInt
    -> CInt
    -> MutableByteArray# RealWorld
    -> CSize
    -> IO (Ptr NewTopic)

-- | Return a @NUL@-terminated human-readable description of the version
-- of @librdkafka@ that was linked to. The memory referenced by the returned
-- pointer does not need to be freed. Calls @rd_kafka_version_str@.
foreign import ccall unsafe "rd_kafka_version_str"
  versionString :: IO (Ptr CChar)

foreign import ccall unsafe "rd_kafka_version"
  rdKafkaVersion :: IO CInt

foreign import ccall safe "rd_kafka_consumer_poll"
  safeRdKafkaConsumerPoll ::
       Ptr Handle
    -> CInt
    -> IO (Ptr Message)

foreign import ccall unsafe "rd_kafka_consumer_poll"
  unsafeRdKafkaConsumerPoll ::
       Ptr Handle
    -> CInt
    -> IO (Ptr Message)

foreign import ccall safe "rd_kafka_poll"
  safeRdKafkaPoll ::
       Ptr Handle
    -> CInt
    -> IO CInt

foreign import ccall unsafe "rd_kafka_poll"
  unsafeRdKafkaPoll ::
       Ptr Handle
    -> CInt
    -> IO CInt

foreign import ccall safe "rd_kafka_queue_poll"
  safeRdKafkaQueuePoll ::
       Ptr Queue
    -> CInt
    -> IO (Ptr Event)

foreign import ccall safe "rd_kafka_flush"
  safeRdKafkaFlush ::
       Ptr Handle
    -> CInt
    -> IO ResponseError

-- | Wrap a delivery report message callback. This allocates storage that
-- is not reclaimed until @freeHaskellFunPtr@ is called.
foreign import ccall "wrapper"
  wrapDeliveryReportMessageCallback ::
       DeliveryReportMessageCallback
    -> IO (FunPtr DeliveryReportMessageCallback)

-- | Wrap a log callback. This allocates storage that
-- is not reclaimed until @freeHaskellFunPtr@ is called.
foreign import ccall "wrapper"
  wrapLogCallback ::
       LogCallback
    -> IO (FunPtr LogCallback)

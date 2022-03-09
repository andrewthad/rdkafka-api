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
  , topicPartitionListSetOffset
  , topicName
  , pollSetConsumer
  , new
  , flush
  , destroy
  , consumerClose
  , subscribe
  , subscription
  , assignment
  , messageDestroy
  , newTopicNew
  , newTopicDestroy
  , eventDestroy
  , createTopic
  , eventType
  , offsetsStore
  , seekPartitions
  , queryWatermarkOffsets
  , version
  , versionString
  , versionByteArray
  , versionByteString
    -- * Poll
  , consumerPoll
  , consumerPollNonblocking
  , poll
  , queuePoll
    -- * Commit Offset
  , commit
  , commitQueue_
    -- * Produce
  , produceBytes
  , produceBytesBlocking
  , produceBytesOpaque
    -- * Headers
  , headersDestroy
  , headersNew
  , headerAdd
    -- * Wrapper
  , wrapDeliveryReportMessageCallback
  , wrapLogCallback
  , wrapOffsetCommitCallback
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
import Data.Int (Int64)
import Data.Kind (Type)
import Data.Primitive (ByteArray(ByteArray),MutableByteArray(MutableByteArray))
import Data.Void (Void)
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
import Rdkafka.Types (EventType,Headers,OffsetCommitCallback)
import Rdkafka.Types (Message,NewTopic,AdminOptions,Queue,Event)
import Rdkafka.Types (ResponseError,Handle,ConfigurationResult)
import Rdkafka.Types (TopicPartitionList,TopicPartition,Topic)
import System.Posix.Types (CSsize(CSsize))

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
--
-- Note: librdkafka copies the topic name, so it does not need to be pinned
-- or stay live.
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
consumerPoll !h !ms =
  safeRdKafkaConsumerPoll h (fromIntegral @Int @CInt ms)

-- | Calls @rd_kafka_commit@ with @async@ to false.
commit ::
     Ptr Handle
  -> Ptr TopicPartitionList
  -> IO ResponseError
commit !h !tpl =
  safeRdKafkaCommit h tpl (0 :: CInt)

-- | Calls @rd_kafka_commit_queue@ with @commit_opaque@ set to @NULL@.
commitQueue_ ::
     Ptr Handle
  -> Ptr TopicPartitionList
  -> Ptr Queue
  -> FunPtr OffsetCommitCallback
  -> IO ResponseError
commitQueue_ !h !tpl !q !cb =
  safeRdKafkaCommitQueue h tpl q cb nullPtr

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
--
-- TODO: Make this crash when given a number larger than 2 billion.
poll ::
     Ptr Handle -- ^ Kafka handle
  -> Int -- ^ Milliseconds to wait for message, @-1@ means wait indefinitely
  -> IO Int
poll !tpl !ms =
  fmap (fromIntegral @CInt @Int) (safeRdKafkaPoll tpl (fromIntegral @Int @CInt ms))

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
  -> Bytes -- ^ Key, empty bytes converted to null key
  -> Ptr Headers
  -> IO ResponseError
anchorPinnedAndPushNonblocking !h extra
    (ManagedCString (ByteArray topic# ))
    (Bytes (ByteArray parr# ) poff plen)
    (Bytes (ByteArray karr# ) koff klen) !hdrs = do
  -- TODO: Use mask to prevent memory leaks
  stable <- newStablePtr $! Opaque extra parr#
  e <- pushNonblockingNoncopyingOpaque h topic# parr# poff plen karr# koff klen hdrs
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
  -> Bytes -- Key, empty bytes converted to null key, precondition: pinned
  -> Ptr Headers
  -> IO ResponseError
anchorPinnedAndPushBlocking !h extra (ManagedCString (ByteArray topic# ))
    (Bytes (ByteArray arr# ) off len)
    (Bytes (ByteArray key# ) koff klen) !hdrs = do
  -- TODO: Use mask to prevent memory leaks
  stable <- newStablePtr $! OpaqueWithTopic extra arr# topic#
  e <- pushBlockingNoncopyingOpaque h topic# arr# off len key# koff klen hdrs
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
  -> Bytes -- ^ Key, empty bytes converted to null key
  -> Ptr Headers
  -> Any -- ^ Opaque value for callback
  -> IO ResponseError
produceBytesOpaque !h !topic
  bs@(Bytes arr@(ByteArray arr# ) off len)
  key@(Bytes (ByteArray karr#) koff klen) !hdrs opaque =
  case PM.isByteArrayPinned arr of
    True -> anchorPinnedAndPushNonblocking h (# | opaque #) topic bs key hdrs
    False -> do
      let !(ByteArray emptyArr#) = mempty
      -- TODO: use mask to prevent memory leaks
      stable <- newStablePtr $! Opaque (# | opaque #) emptyArr#
      e <- pushNonblockingCopyingOpaque h topic# arr# off len karr# koff klen hdrs
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
  -> Bytes -- ^ Key, empty bytes converted to null key
  -> Ptr Headers -- ^ Headers
  -> IO ResponseError
produceBytes !h !topic
  bs@(Bytes arr@(ByteArray arr# ) off len)
  key@(Bytes (ByteArray karr#) koff klen) !hdrs =
  case PM.isByteArrayPinned arr of
    True -> anchorPinnedAndPushNonblocking h (# (# #) | #) topic bs key hdrs
    False -> pushNonblockingCopyingNoOpaque h topic# arr# off len karr# koff klen hdrs
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
  -> Bytes -- ^ Key, empty bytes converted to null key
  -> Ptr Headers -- ^ Headers
  -> IO ResponseError
produceBytesBlocking !h !topic !b0 !key0 !hdrs =
  anchorPinnedAndPushBlocking h (# (# #) | #) (ManagedCString.pin topic) b1 key1 hdrs
  where
  !b1 = Bytes.pin b0
  !key1 = Bytes.pin key0

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

-- | Query broker for low (oldest/beginning) and high (newest/end) offsets for partition.
-- Offsets are returned in @low@ and @high@ respectively.
queryWatermarkOffsets ::
     Ptr Handle
  -> ManagedCString -- ^ Topic name
  -> Partition -- ^ Partition
  -> Ptr Int64 -- ^ Earliest offset, output parameter
  -> Ptr Int64 -- ^ Latest offset, output parameter
  -> CInt -- ^ Timeout in milliseconds
  -> IO ResponseError
queryWatermarkOffsets !h (ManagedCString (ByteArray name)) p s e timeout =
  safeQueryWatermarkOffsets h name p s e timeout

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
    -> ByteArray# -- message
    -> Int -- message offset
    -> Int -- message length
    -> ByteArray# -- key
    -> Int -- key offset
    -> Int -- key length
    -> Ptr Headers
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_noncopying_opaque"
  pushNonblockingNoncopyingOpaque ::
       Ptr Handle
    -> ByteArray# -- topic
    -> ByteArray# -- message
    -> Int -- message offset
    -> Int -- message length
    -> ByteArray# -- key
    -> Int -- key offset
    -> Int -- key length
    -> Ptr Headers
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_copying_opaque"
  pushNonblockingCopyingOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray# -- message
    -> Int -- message offset
    -> Int -- message length
    -> ByteArray# -- key
    -> Int -- key offset
    -> Int -- key length
    -> Ptr Headers
    -> MessageOpaque
    -> IO ResponseError

foreign import ccall unsafe "hsrdk_push_nonblocking_copying_no_opaque"
  pushNonblockingCopyingNoOpaque ::
       Ptr Handle
    -> ByteArray#
    -> ByteArray# -- message
    -> Int -- message offset
    -> Int -- message length
    -> ByteArray# -- key
    -> Int -- key offset
    -> Int -- key length
    -> Ptr Headers
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

-- | Calls @rd_kafka_subscription@.
foreign import ccall unsafe "rd_kafka_subscription"
  subscription ::
       Ptr Handle -- ^ Kafka handle
    -> Ptr (Ptr TopicPartitionList) -- ^ Topics, output param
    -> IO ResponseError

-- | Calls @rd_kafka_assignment@.
foreign import ccall unsafe "rd_kafka_assignment"
  assignment ::
       Ptr Handle -- ^ Kafka handle
    -> Ptr (Ptr TopicPartitionList) -- ^ Topics, output param
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

-- | Calls @rd_kafka_topic_partition_list_destroy@.
foreign import ccall unsafe "rd_kafka_topic_partition_list_set_offset"
  topicPartitionListSetOffset ::
       Ptr TopicPartitionList -- ^ Topics
    -> ByteArray# -- ^ Topic name, must have NUL terminator
    -> Partition -- ^ Partition
    -> Int64 -- ^ Offset
    -> IO ResponseError

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

foreign import ccall safe "rd_kafka_commit"
  safeRdKafkaCommit ::
       Ptr Handle
    -> Ptr TopicPartitionList
    -> CInt
    -> IO ResponseError

foreign import ccall safe "rd_kafka_commit_queue"
  safeRdKafkaCommitQueue ::
       Ptr Handle
    -> Ptr TopicPartitionList
    -> Ptr Queue
    -> FunPtr OffsetCommitCallback
    -> Ptr Void
    -> IO ResponseError

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

-- | Calls @rd_kafka_headers_new@.
foreign import ccall unsafe "rd_kafka_headers_new"
  headersNew ::
       CSize
    -> IO (Ptr Headers)

-- | Calls @rd_kafka_header_add@.
foreign import ccall unsafe "rd_kafka_header_add"
  headerAdd ::
       Ptr CChar -- name
    -> CSsize -- name size
    -> Ptr Void -- value
    -> CSsize -- value size
    -> IO (Ptr Headers)

-- | Calls @rd_kafka_headers_destroy@.
foreign import ccall unsafe "rd_kafka_headers_destroy"
  headersDestroy ::
       Ptr Headers
    -> IO ()

-- | Calls @rd_kafka_offsets_store@.
foreign import ccall unsafe "rd_kafka_offsets_store"
  offsetsStore ::
       Ptr Handle
    -> Ptr TopicPartitionList
    -> IO ResponseError

-- | Calls @rd_kafka_seek_partitions@.
foreign import ccall safe "rd_kafka_seek_partitions"
  seekPartitions ::
       Ptr Handle
    -> Ptr TopicPartitionList -- ^ Partitions
    -> CInt -- ^ Timeout in milliseconds
    -> IO ResponseError

foreign import ccall safe "rd_kafka_query_watermark_offsets"
  safeQueryWatermarkOffsets ::
     Ptr Handle
  -> ByteArray# -- ^ Topic name
  -> Partition -- ^ Partition
  -> Ptr Int64 -- ^ Earliest offset, output parameter
  -> Ptr Int64 -- ^ Latest offset, output parameter
  -> CInt -- ^ Timeout in milliseconds
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


-- | Wrap a delivery report message callback. This allocates storage that
-- is not reclaimed until @freeHaskellFunPtr@ is called.
foreign import ccall "wrapper"
  wrapOffsetCommitCallback ::
       OffsetCommitCallback
    -> IO (FunPtr OffsetCommitCallback)


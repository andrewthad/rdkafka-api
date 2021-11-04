{-# language DerivingStrategies #-}
{-# language GeneralizedNewtypeDeriving #-}

module Rdkafka.Types
  ( -- * Enums
    ResponseError(..)
  , ConfigurationResult(..)
  , Type(..)
  , EventType(..)
    -- * Newtypes
  , Partition(..)
    -- * Phantom Types
  , AdminOptions
  , Configuration
  , Event
  , Handle
  , Headers
  , Message
  , NewTopic
  , Queue
  , Topic
  , TopicPartition
  , TopicPartitionList
  , ValueUnion
    -- * Special Types
  , MessageOpaque(..)
    -- * Callbacks
  , LogCallback
  , DeliveryReportMessageCallback
  ) where

import Data.Int (Int32)
import Data.Void (Void)
import Foreign.Ptr (Ptr)
import Foreign.C.Types (CInt)
import Foreign.C.String (CString)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Storable (Storable)

import Rdkafka.Constant.ResponseError (ResponseError(..))

newtype Partition = Partition Int32

-- | Corresponds to @rd_kafka_conf_res_t@.
newtype ConfigurationResult = ConfigurationResult CInt
  deriving newtype (Eq)

-- | Corresponds to @rd_kafka_event_type_t@.
newtype EventType = EventType CInt
  deriving newtype (Eq)

-- | Corresponds to @rd_kafka_type_t@.
newtype Type = Type CInt

-- | Corresponds to @rd_kafka_t@. Phantom type for pointers.
data Handle

-- | Corresponds to @rd_kafka_headers_t@. Phantom type for pointers.
data Headers

-- | Corresponds to @rd_kafka_conf_t@. Phantom type for pointers.
data Configuration

-- | Corresponds to @rd_kafka_message_t@. Phantom type for pointers.
data Message

-- | Corresponds to @rd_kafka_vu_t@. Phantom type for pointers.
data ValueUnion

-- | Corresponds to @rd_kafka_topic_partition_list_t@. Phantom type for pointers.
data TopicPartitionList

-- | Corresponds to @rd_kafka_NewTopic_t@. Phantom type for pointers.
data NewTopic

-- | Corresponds to @rd_kafka_topic_partition_t@. Phantom type for pointers.
data TopicPartition

-- | Corresponds to @rd_kafka_topic_t@. Phantom type for pointers.
data Topic

-- | Corresponds to @rd_kafka_AdminOptions_t@. Phantom type for pointers.
data AdminOptions

-- | Corresponds to @rd_kafka_queue_t@. Phantom type for pointers.
data Queue

-- | Corresponds to @rd_kafka_event_t@. Phantom type for pointers.
data Event

-- | Does not correspond to a type from @librdkafka@. This is used as
-- @msg_opaque@. The pointer inside cannot be derefenced. It is only
-- ever casted to @StablePtr@. During delivery callbacks, users must call
-- @unanchorMessage@, which allows the garbage collector to reclaim
-- the payload.
--
-- Note that the per-handle opaque value (the third argument of a
-- delivery report message callback) does not get the same level of
-- special treatment in this library. This is because, in GHC,
-- per-message opaque values can be set to a @StablePtr@ that keeps
-- the message live. This only works when the byte array backing the
-- message is pinned. This need is common and the implementation is
-- tricky. Consequently, this library takes an opinionated stance and
-- does this under the hood, copying unpinned payloads with
-- @RD_KAFKA_MSG_F_COPY@ and passing pinned payloads over using
-- @StablePtr@ to guarantee that they remain live.
newtype MessageOpaque = MessageOpaque (Ptr ())

-- | A callback that can be passed to @rd_kafka_conf_set_log_cb@. The
-- arguments are:
--
-- * Kafka handle
-- * Log level
-- * @NUL@-terminated facility description
-- * @NUL@-terminated message
type LogCallback = Ptr Handle -> CInt -> CString -> CString -> IO ()

-- | A callback that can be passed to @rd_kafka_conf_set_dr_msg_cb@. The
-- arguments are:
--
-- * Kafka handle
-- * Information about the success or failure of message delivery. A callback
--   should always call @peekPrivate@ on this argument and then 
-- * The per-handle opaque value (@unanchorPayload@ must be called on this)
type DeliveryReportMessageCallback =
  Ptr Handle -> Ptr Message -> Ptr Void -> IO ()

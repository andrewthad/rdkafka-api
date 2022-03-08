#include <librdkafka/rdkafka.h>

{-# language BangPatterns #-}

-- | Message corresponds to @rd_kafka_message_t@ and has these fields:
--
-- > int                          cnt
-- > int                          size
-- > rd_kafka_topic_partition_t * elems
module Rdkafka.Struct.TopicPartitionList
  ( -- * Peek at Fields
    peekCount
  , peekSize
  , peekElements
    -- * Derived Combinators
  , traverse_
  ) where

import Data.Int (Int64)
import Data.Void (Void)
import Foreign.C.Types (CSize,CInt)
import Foreign.Ptr (Ptr,plusPtr)
import Foreign.Storable (peekByteOff,peekElemOff)
import Rdkafka.Types (Topic,Message,ResponseError,TopicPartitionList,TopicPartition)

-- | Get field @cnt@
peekCount :: Ptr TopicPartitionList -> IO (Ptr CInt)
peekCount = #{peek rd_kafka_topic_partition_list_t, cnt}

-- | Get field @size@
peekSize :: Ptr TopicPartitionList -> IO (Ptr CInt)
peekSize = #{peek rd_kafka_topic_partition_list_t, size}

-- | Get field @elems@
peekElements :: Ptr TopicPartitionList -> IO (Ptr TopicPartition)
peekElements = #{peek rd_kafka_topic_partition_list_t, elems}

traverse_ :: (Ptr TopicPartition -> IO a) -> Ptr TopicPartitionList -> IO ()
traverse_ f tpl = do
  total0 <- peekCount tpl
  let !total = fromIntegral total :: Int
  tps <- peekElements tpl
  go 0 total tps
  where
  go :: Int -> Int -> Ptr TopicPartition -> IO ()
  go !ix !total !tps = if ix < total
    then do
      _ <- f tps
      go (ix + 1) total (plusPtr tps #{size rd_kafka_topic_partition_t})
    else pure ()

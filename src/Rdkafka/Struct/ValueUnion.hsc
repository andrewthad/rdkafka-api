#include <librdkafka/rdkafka.h>
{-# language BangPatterns #-}

-- | ValueUnion corresponds to @rd_kafka_vu_t@. This struct is 
-- a C-style tagged union. A tag named @vtype@ determines how
-- the union should be interpreted. In these bindings, we only
-- provide functions that set ValueUnion pointers. Users should never
-- need to retrieve the value at the pointers since this data type
-- is only used to pass arguments. These setters are given names
-- that are not prefixed with poke as a reminder that they do not
-- just set a field. They also set the @vtype@. It never makes
-- sense to use more than one setter on a ValueUnion pointer.
module Rdkafka.Struct.ValueUnion
  ( setTopic
  , setPartition
  , setOpaque
  , setTimestamp
  , setMessageFlags
  , setHeader
  , setKey
  ) where

import Data.Int (Int32,Int64)
import Data.Void (Void)
import Foreign.Ptr (Ptr)
import Foreign.Storable (peekByteOff,pokeByteOff)
import Foreign.C.Types (CChar,CInt,CSize)
import System.Posix.Types (CSsize)
import Rdkafka.Types (ValueUnion,MessageOpaque)

-- | Set the value union to a topic (@RD_KAFKA_VTYPE_TOPIC@).
setTopic :: Ptr ValueUnion -> Ptr CChar -> IO ()
setTopic !ptr !val = do
  #{poke rd_kafka_vu_t, u.cstr} ptr val
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_TOPIC} :: CInt)

-- | Set the value union to a partition (@RD_KAFKA_VTYPE_PARTITION@).
setPartition :: Ptr ValueUnion -> Int32 -> IO ()
setPartition !ptr !val = do
  #{poke rd_kafka_vu_t, u.i32} ptr val
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_PARTITION} :: CInt)

-- | Set the value union to a partition (@RD_KAFKA_VTYPE_PARTITION@).
setOpaque :: Ptr ValueUnion -> Ptr MessageOpaque -> IO ()
setOpaque !ptr !val = do
  #{poke rd_kafka_vu_t, u.ptr} ptr val
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_OPAQUE} :: CInt)

-- | Set the value union to a timestamp (@RD_KAFKA_VTYPE_TIMESTAMP@).
setTimestamp :: Ptr ValueUnion -> Int64 -> IO ()
setTimestamp !ptr !val = do
  #{poke rd_kafka_vu_t, u.i64} ptr val
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_TIMESTAMP} :: CInt)

-- | Set the value union to message flags (@RD_KAFKA_VTYPE_MSGFLAGS@).
setMessageFlags :: Ptr ValueUnion -> CInt -> IO ()
setMessageFlags !ptr !val = do
  #{poke rd_kafka_vu_t, u.i} ptr val
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_MSGFLAGS} :: CInt)

-- | Set the value union to a header (@RD_KAFKA_VTYPE_HEADER@).
setHeader ::
     Ptr ValueUnion
  -> Ptr CChar -- ^ Name (@NUL@ terminated)
  -> Ptr Void -- ^ Value pointer
  -> CSsize -- ^ Value length
  -> IO ()
setHeader !ptr !name !val !valLen = do
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_HEADER} :: CInt)
  #{poke rd_kafka_vu_t, u.header.name} ptr name
  #{poke rd_kafka_vu_t, u.header.val} ptr val
  #{poke rd_kafka_vu_t, u.header.size} ptr valLen

-- | Set the value union to a key (@RD_KAFKA_VTYPE_KEY@).
setKey ::
     Ptr ValueUnion
  -> Ptr Void -- ^ Key pointer
  -> CSize -- ^ Key length
  -> IO ()
setKey !ptr !val !valLen = do
  #{poke rd_kafka_vu_t, vtype} ptr ( #{const RD_KAFKA_VTYPE_KEY} :: CInt)
  #{poke rd_kafka_vu_t, u.mem.ptr} ptr val
  #{poke rd_kafka_vu_t, u.mem.size} ptr valLen

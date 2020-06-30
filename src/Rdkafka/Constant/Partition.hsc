#include <librdkafka/rdkafka.h>

{-# language PatternSynonyms #-}

module Rdkafka.Constant.Partition
  ( pattern Unassigned
  ) where

import Rdkafka.Types (Partition(Partition))

pattern Unassigned :: Partition
pattern Unassigned = Partition ( #{const RD_KAFKA_PARTITION_UA} )

#include <librdkafka/rdkafka.h>

{-# language PatternSynonyms #-}

module Rdkafka.Constant.Type
  ( pattern Producer
  ) where

import Rdkafka.Types (Type(Type))

pattern Producer :: Type
pattern Producer = Type #{const RD_KAFKA_PRODUCER}



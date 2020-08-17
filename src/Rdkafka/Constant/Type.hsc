#include <librdkafka/rdkafka.h>

{-# language PatternSynonyms #-}

module Rdkafka.Constant.Type
  ( pattern Consumer
  , pattern Producer
  ) where

import Rdkafka.Types (Type(Type))

pattern Producer :: Type
pattern Producer = Type #{const RD_KAFKA_PRODUCER}

pattern Consumer :: Type
pattern Consumer = Type #{const RD_KAFKA_CONSUMER}

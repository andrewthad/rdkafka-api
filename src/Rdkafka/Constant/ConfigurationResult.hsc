#include <librdkafka/rdkafka.h>

{-# language PatternSynonyms #-}

module Rdkafka.Constant.ConfigurationResult
  ( pattern Ok
  , pattern Invalid
  , pattern Unknown
  ) where

import Rdkafka.Types (ConfigurationResult(ConfigurationResult))

pattern Ok :: ConfigurationResult
pattern Ok = ConfigurationResult ( #{const RD_KAFKA_CONF_OK} )

pattern Invalid :: ConfigurationResult
pattern Invalid = ConfigurationResult ( #{const RD_KAFKA_CONF_INVALID} )

pattern Unknown :: ConfigurationResult
pattern Unknown = ConfigurationResult ( #{const RD_KAFKA_CONF_UNKNOWN} )


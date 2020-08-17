module Rdkafka.Client.Types
  ( Producer(..)
  , Consumer(..)
  ) where

import Foreign.Ptr (Ptr)
import qualified Rdkafka.Types as T

newtype Producer = Producer (Ptr T.Handle)
newtype Consumer = Consumer (Ptr T.Handle)

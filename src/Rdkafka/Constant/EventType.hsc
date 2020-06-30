#include <librdkafka/rdkafka.h>

{-# language PatternSynonyms #-}

module Rdkafka.Constant.EventType
  ( pattern CreateTopicsResult
  ) where

import Rdkafka.Types (EventType(EventType))

pattern CreateTopicsResult :: EventType
pattern CreateTopicsResult = EventType ( #{const RD_KAFKA_EVENT_CREATETOPICS_RESULT} )

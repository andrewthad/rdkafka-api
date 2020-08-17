{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}

module Rdkafka.Client.Producer
  ( bytes
  , flush
  , close
  , pollNonblocking
  ) where

import Data.Bytes (Bytes)
import Foreign.C.String.Managed (ManagedCString)
import Rdkafka.Client.Types (Producer(Producer))
import Rdkafka.Types (ResponseError)
import GHC.IO (IO(IO))
import GHC.Exts (raiseIO#)
import Control.Exception (toException)

import qualified Rdkafka as X
import qualified Rdkafka.Constant.ResponseError as ResponseError

-- | Produce a single message. If the rdkafka's local message queue
-- is full, blocks until the message can be enqueued. This never
-- returns 'ResponseError.QueueFull' (@RD_KAFKA_RESP_ERR__QUEUE_FULL@).
bytes ::
     Producer
  -> ManagedCString -- ^ Topic name
  -> Bytes -- ^ Message
  -> IO (Either ResponseError ())
bytes (Producer h) !topic !b = X.produceBytes h topic b >>= \case
  ResponseError.QueueFull -> X.produceBytesBlocking h topic b >>= \case
    ResponseError.NoError -> pure (Right ())
    ResponseError.QueueFull -> IO (raiseIO# (toException (userError "Rdkafka.Client.Producer.bytes: unexpected QueueFull error")))
    e -> pure (Left e)
  ResponseError.NoError -> pure (Right ())
  e -> pure (Left e)

-- | Block until all pending messages have been delivered.
--
-- ==== __Implementation__
--
-- This is a hack. We actually only block for 60000 seconds. Also,
-- @rdkafka@ has a problem with huge timeouts. Integer overflows
-- messes them up.
flush :: Producer -> IO (Either ResponseError ())
flush (Producer h) = X.flush h 60000 >>= \case
  ResponseError.NoError -> pure (Right ())
  e -> pure (Left e)

-- | Calls @rd_kafka_destroy@. Blocks until any in-flight messages
-- have had callbacks called.
close :: Producer -> IO ()
close (Producer h) = X.destroy h

-- | Calls @rd_kafka_poll@, returning immidiately if no messages
-- are on the queue. Returns the number of events served.
pollNonblocking ::
     Producer
  -> IO Int
pollNonblocking (Producer h) = X.pollNonblocking h

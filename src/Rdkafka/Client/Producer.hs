{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language MagicHash #-}

module Rdkafka.Client.Producer
  ( bytes
  , flush
  , close
  , poll
  ) where

import Data.Bytes (Bytes)
import Foreign.C.String.Managed (ManagedCString)
import Rdkafka.Client.Types (Producer(Producer))
import Rdkafka.Types (ResponseError,Headers)
import GHC.IO (IO(IO))
import GHC.Exts (Ptr,raiseIO#)
import Control.Exception (toException)

import qualified Rdkafka as X
import qualified Rdkafka.Constant.ResponseError as ResponseError

-- | Produce a single message. If the rdkafka's local message queue
-- is full, blocks until the message can be enqueued. This never
-- returns 'ResponseError.QueueFull' (@RD_KAFKA_RESP_ERR__QUEUE_FULL@).
-- This always frees the headers regardless of whether production is
-- successful or unsuccessful.
--
-- It is common to set @key@ to the empty byte sequences (treated by
-- this library as no key) and @headers@ to @nullPtr@.
bytes ::
     Producer
  -> ManagedCString -- ^ Topic name
  -> Bytes -- ^ Key, use empty bytes for no key
  -> Ptr Headers -- ^ Headers, use 'nullPtr' for no headers
  -> Bytes -- ^ Message
  -> IO (Either ResponseError ())
bytes (Producer h) !topic !key !hdrs !b = X.produceBytes h topic b key hdrs >>= \case
  ResponseError.QueueFull -> X.produceBytesBlocking h topic b key hdrs >>= \case
    ResponseError.NoError -> pure (Right ())
    ResponseError.QueueFull -> IO (raiseIO# (toException (userError "Rdkafka.Client.Producer.bytes: unexpected QueueFull error")))
    e -> finishWithError e
  ResponseError.NoError -> pure (Right ())
  e -> finishWithError e
  where
  finishWithError :: ResponseError -> IO (Either ResponseError ())
  finishWithError !e = do
    X.headersDestroy hdrs
    pure (Left e)
  

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

-- | Calls @rd_kafka_poll@, returning immidiately if no messages are
-- on the queue Returns the number of events served. This does not wait for
-- Use this in a loop with @threadDelay@ between invocations.
poll ::
     Producer
  -> IO Int
poll (Producer h) = X.poll h 0

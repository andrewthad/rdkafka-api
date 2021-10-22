{-# language BangPatterns #-}
{-# language DeriveFunctor #-}
{-# language DerivingStrategies #-}
{-# language LambdaCase #-}

module Rdkafka.Client.Configuration
  ( -- * Type
    Configure(..)
    -- * Consume Configuration
  , run
  , producer
  , consumer
    -- * Create Configuration
  , set
  , setLogCallback
  , setDeliveryReportMessageCallback
  ) where

import Control.Applicative (liftA2)
import GHC.Exts (RealWorld)
import Data.Bytes (Bytes)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Ptr (FunPtr,Ptr,nullPtr)
import Rdkafka.Types (Configuration,LogCallback,DeliveryReportMessageCallback,Type)
import Rdkafka.Client.Types (Producer(Producer),Consumer(Consumer))

import qualified Rdkafka as X
import qualified Rdkafka.Types as T
import qualified Rdkafka.Constant.ConfigurationResult as ConfigurationResult
import qualified Rdkafka.Constant.Type as Type
import qualified Data.Primitive as PM

-- | An action that builds a the configuration used for either
-- a producer or a consumer.
--
-- ==== __Implementation__
--
-- Understood as a classic monad transformer stack, this is a combination
-- of @ReaderT@ (environment of @Ptr Configuration@ and @MutableByteArray@),
-- @MaybeT@ (failure), and IO (arbitrary effects). The additional invariant
-- layered on top of this is that any operation that fails (returns @Nothing@)
-- must also write a description of the failure to the mutable byte array.
-- This is how @rd_kafka_conf_set@ works, and @Configure@ is designed to
-- capture that pattern in such a way that the common paramaters to each
-- function are threaded through implicitly.
data Configure a = Configure (Ptr Configuration -> PM.MutableByteArray RealWorld -> IO (Maybe a))
  deriving stock (Functor)

instance Applicative Configure where
  pure a = Configure (\_ _ -> pure (Just a))
  Configure f <*> Configure g = Configure
    (\conf errorBuffer -> f conf errorBuffer >>= \case
      Nothing -> pure Nothing
      Just h -> g conf errorBuffer >>= \case
        Nothing -> pure Nothing
        Just r -> pure (Just (h r))
    )

instance Monad Configure where
  Configure f >>= g = Configure
    (\conf errorBuffer -> f conf errorBuffer >>= \case
      Nothing -> pure Nothing
      Just a -> case g a of
        Configure h -> h conf errorBuffer
    )

instance Semigroup a => Semigroup (Configure a) where
  (<>) = liftA2 (<>)

errorBufferSize :: Int
errorBufferSize = 512

-- | Build a 'Configuration' by running the 'Configure' action. This
-- never returns a null pointer. Most users should prefer 'handle'.
run :: Configure () -> IO (Either Bytes (Ptr Configuration))
{-# inline run #-}
run (Configure f) = do
  conf <- X.configurationNew
  errorBuffer <- PM.newByteArray errorBufferSize
  f conf errorBuffer >>= \case
    Nothing -> fmap Left (X.finalizeErrorBuffer errorBuffer)
    Just _ -> pure (Right conf)

-- | Variant of 'run' that builds the configuration and then calls
-- @rd_kafka_new@, handling errors appropriately. This never returns
-- a null pointer.
producer :: Configure () -> IO (Either Bytes Producer)
{-# inline producer #-}
producer c = (fmap.fmap) Producer (handle Type.Producer c)

-- | Variant of 'run' that builds the configuration and then calls
-- @rd_kafka_new@, handling errors appropriately. This never returns
-- a null pointer.
--
-- Note: This calls @rd_kafka_poll_set_consumer@ on the handle that
-- backs the consumer.
consumer :: Configure () -> IO (Either Bytes Consumer)
{-# inline consumer #-}
consumer c = handle Type.Consumer c >>= \case
  Left err -> pure (Left err)
  Right p -> do
    X.pollSetConsumer p
    pure (Right (Consumer p))

handle :: Type -> Configure () -> IO (Either Bytes (Ptr T.Handle))
{-# inline handle #-}
handle !ty (Configure f) = do
  conf <- X.configurationNew
  errorBuffer <- PM.newByteArray errorBufferSize
  f conf errorBuffer >>= \case
    Nothing -> fmap Left (X.finalizeErrorBuffer errorBuffer)
    Just _ -> do
      ptr <- X.new ty conf errorBuffer errorBufferSize
      if ptr == nullPtr
        then fmap Left (X.finalizeErrorBuffer errorBuffer)
        else pure (Right ptr)

-- | Sets a configuration property. Calls @rd_kafka_conf_set@.
set ::
     ManagedCString -- ^ Name
  -> ManagedCString -- ^ Value
  -> Configure ()
set !name !val = Configure
  (\ !conf !errorBuffer ->
    X.configurationSet conf name val errorBuffer errorBufferSize >>= \case
      ConfigurationResult.Ok -> pure (Just ())
      _ -> pure Nothing
  )

-- | Calls @rd_kafka_conf_set_log_cb@.
setLogCallback ::
     FunPtr LogCallback -- ^ Callback
  -> Configure ()
setLogCallback !cb = Configure
  (\ !conf !_ -> fmap Just (X.configurationSetLogCallback conf cb)
  )

-- | Calls @rd_kafka_conf_set_dr_msg_cb@.
setDeliveryReportMessageCallback ::
     FunPtr DeliveryReportMessageCallback -- ^ Callback
  -> Configure ()
setDeliveryReportMessageCallback !cb = Configure
  (\ !conf !_ -> fmap Just (X.configurationSetDeliveryReportMessageCallback conf cb)
  )

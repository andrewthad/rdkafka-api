{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language NumericUnderscores #-}
{-# language OverloadedStrings #-}

import Control.Concurrent (threadDelay)
import Data.Bytes (Bytes)
import Data.Foldable (for_)
import Data.Primitive (MutableByteArray)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Ptr (Ptr,FunPtr,nullPtr)
import GHC.Clock (getMonotonicTimeNSec)
import GHC.Exts (RealWorld,Any)
import Rdkafka.Types (Handle,ConfigurationResult)
import Rdkafka.Types (DeliveryReportMessageCallback)
import System.Environment (getArgs)
import Unsafe.Coerce (unsafeCoerce)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.State (StateT(StateT),evalStateT,get,put)

import qualified Data.Bytes as Bytes
import qualified Data.Bytes.Chunks as Chunks
import qualified Data.List as List
import qualified Foreign.C.String.Managed as MCS
import qualified Data.Primitive as PM
import qualified GHC.Exts as Exts
import qualified Rdkafka as K
import qualified Rdkafka.Constant.ResponseError as ResponseError
import qualified Rdkafka.Constant.ConfigurationResult as ConfigurationResult
import qualified Rdkafka.Constant.Type as Type
import qualified Rdkafka.Struct.Message as Message
import qualified System.IO as IO

data Option
  = LogOnDelivery
  | AugmentOpaque
  deriving Eq

data Extra = Extra
  {-# UNPACK #-} !Int -- line number
  {-# UNPACK #-} !Bytes -- contents of line

main :: IO ()
main = do
  (broker,topic,extra) <- getArgs >>= \case
    [broker,topic] ->
      pure (MCS.fromLatinString broker,MCS.fromLatinString topic,[])
    [broker,topic,extra] -> do
      let acc0 = []
          acc1 = if List.elem 'd' extra then LogOnDelivery : acc0 else acc0
          acc2 = if List.elem 'a' extra then AugmentOpaque : acc1 else acc1
      pure (MCS.fromLatinString broker,MCS.fromLatinString topic,acc2)
    _ -> fail "Please provide a broker and a topic as arguments"
  input <- Chunks.hGetContents IO.stdin
  let logOnDelivery = List.elem LogOnDelivery extra
  let augmentOpaque = List.elem AugmentOpaque extra
  version <- K.versionByteArray
  putStr ("librdkafka version: ")
  Bytes.hPut IO.stdout (Bytes.fromByteArray version)
  putStrLn ("\nBroker: " ++ show broker)
  putStrLn ("Topic: " ++ show topic)
  putStrLn ("Log on delivery: " ++ show logOnDelivery)
  drcb <- allocateDeliveryCallback logOnDelivery
  rk <- initialize broker drcb
  flip evalStateT 0 $ for_ (Chunks.split 0x0A input) $ \msg -> if Bytes.null msg
    then pure ()
    else do
      ix <- get
      lift (produceOrDie rk topic msg ix augmentOpaque)
      put (ix + 1)
  K.flush rk 5_000_000 >>= \case
    ResponseError.NoError -> putStrLn "Flush succeeded"
    _ -> fail "Flush failed"
  K.destroy rk
  putStrLn "Destroy succeeded"

-- If argument is true, then we log successes.
allocateDeliveryCallback :: Bool -> IO (FunPtr DeliveryReportMessageCallback)
allocateDeliveryCallback = \case
  True -> K.wrapDeliveryReportMessageCallback loggingDeliveryCallback
  False -> K.wrapDeliveryReportMessageCallback nonloggingDeliveryCallback

nonloggingDeliveryCallback :: DeliveryReportMessageCallback
nonloggingDeliveryCallback _ msg _ = do
  opaque <- Message.peekPrivate msg
  K.destroyMessageOpaque_ opaque

loggingDeliveryCallback :: DeliveryReportMessageCallback
loggingDeliveryCallback _ msg _ = do
  opaque <- Message.peekPrivate msg
  K.destroyMessageOpaque opaque >>= \case
    Nothing ->
      Bytes.hPut IO.stdout (Bytes.fromLatinString "Delivered. No opaque value.\n")
    Just a -> do
      let Extra ix b = anyToExtra a
      Bytes.hPut IO.stdout $ mconcat
        [ Bytes.fromLatinString "Delivered line "
        , Bytes.fromLatinString (show ix)
        , Bytes.fromLatinString ": "
        , b
        , Bytes.fromLatinString "\n"
        ]

initialize :: ManagedCString -> FunPtr DeliveryReportMessageCallback -> IO (Ptr Handle)
initialize !broker !drcb = do
  conf <- K.configurationNew
  let errBufLen = 512
  errBuf <- PM.newByteArray errBufLen
  K.configurationSet conf "bootstrap.servers" broker errBuf errBufLen
    >>= failOnBadConf errBuf
  K.configurationSet conf "log_level" "6" errBuf errBufLen
    >>= failOnBadConf errBuf
  K.configurationSetDeliveryReportMessageCallback conf drcb
  K.new Type.Producer conf errBuf errBufLen >>= failOnNull errBuf

failOnBadConf :: MutableByteArray RealWorld -> ConfigurationResult -> IO ()
failOnBadConf errBuf = \case
  ConfigurationResult.Ok -> pure ()
  _ -> do
    errMsg <- K.finalizeErrorBuffer errBuf
    fail (Bytes.toLatinString errMsg)

failOnNull :: MutableByteArray RealWorld -> Ptr a -> IO (Ptr a)
failOnNull errBuf p = if p == nullPtr
  then do
    errMsg <- K.finalizeErrorBuffer errBuf
    fail (Bytes.toLatinString errMsg)
  else pure p

produceOrDie :: Ptr Handle -> ManagedCString -> Bytes -> Int -> Bool -> IO ()
produceOrDie !rk !topic !msg !ix !augment = do
  _ <- K.pollNonblocking rk
  let !extra = extraToAny (Extra ix msg)
  r <- if augment
    then K.produceBytesOpaque rk topic msg extra
    else K.produceBytes rk topic msg
  case r of
    ResponseError.NoError -> pure ()
    ResponseError.QueueFull -> do
      threadDelay 200_000
      produceOrDie rk topic msg ix augment
    _ -> fail "produceOrDie could not produce message"

extraToAny :: Extra -> Any
extraToAny = unsafeCoerce

anyToExtra :: Any -> Extra
anyToExtra = unsafeCoerce

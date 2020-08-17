{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language NumericUnderscores #-}
{-# language OverloadedStrings #-}

import Control.Concurrent (threadDelay)
import Control.Exception (throwIO)
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
import Rdkafka.Client.Types (Producer)

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
import qualified Rdkafka.Client.Producer as Producer
import qualified Rdkafka.Client.Configuration as Configuration
import qualified System.IO as IO

data Option
  = LogOnDelivery
  deriving Eq

main :: IO ()
main = do
  (broker,topic,extra) <- getArgs >>= \case
    [broker,topic] ->
      pure (MCS.fromLatinString broker,MCS.fromLatinString topic,[])
    [broker,topic,extra] -> do
      let acc0 = []
          acc1 = if List.elem 'd' extra then LogOnDelivery : acc0 else acc0
      pure (MCS.fromLatinString broker,MCS.fromLatinString topic,acc1)
    _ -> fail "Please provide a broker and a topic as arguments"
  input <- Chunks.hGetContents IO.stdin
  let logOnDelivery = List.elem LogOnDelivery extra
  version <- K.versionByteArray
  putStr ("librdkafka version: ")
  Bytes.hPut IO.stdout (Bytes.fromByteArray version)
  putStrLn ("\nBroker: " ++ show broker)
  putStrLn ("Topic: " ++ show topic)
  putStrLn ("Log on delivery: " ++ show logOnDelivery)
  drcb <- allocateDeliveryCallback logOnDelivery
  rk <- either throwBytesIO pure =<< initialize broker drcb
  for_ (Chunks.split 0x0A input) $ \msg -> if Bytes.null msg
    then pure ()
    else produceOrDie rk topic msg
  either throwIO pure =<< Producer.flush rk 
  Producer.close rk
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
  K.destroyMessageOpaque_ opaque
  Bytes.hPut IO.stdout (Bytes.fromLatinString "Delivered. No opaque value.\n")

initialize ::
     ManagedCString
  -> FunPtr DeliveryReportMessageCallback
  -> IO (Either Bytes Producer)
initialize !broker !drcb = Configuration.producer $ do
  Configuration.set "bootstrap.servers" broker
  Configuration.set "log_level" "6"
  Configuration.setDeliveryReportMessageCallback drcb

produceOrDie :: Producer -> ManagedCString -> Bytes -> IO ()
produceOrDie !p !topic !msg = do
  _ <- Producer.pollNonblocking p
  either throwIO pure =<< Producer.bytes p topic msg

throwBytesIO :: Bytes -> IO a
throwBytesIO b = do
  Bytes.hPut IO.stderr b
  fail "dieing"

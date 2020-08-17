{-# language BangPatterns #-}
{-# language LambdaCase #-}
{-# language NumericUnderscores #-}
{-# language OverloadedStrings #-}

import Control.Exception (throwIO)
import Control.Monad (when)
import Control.Concurrent (rtsSupportsBoundThreads)
import Data.Bytes (Bytes)
import Data.Primitive (MutableByteArray)
import Foreign.C.String.Managed (ManagedCString)
import Foreign.Ptr (Ptr,FunPtr,nullPtr)
import GHC.Clock (getMonotonicTimeNSec)
import GHC.Exts (RealWorld,Any)
import Rdkafka.Types (Handle,ConfigurationResult,ResponseError)
import Rdkafka.Types (DeliveryReportMessageCallback)
import System.Environment (getArgs)
import Unsafe.Coerce (unsafeCoerce)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.State (StateT(StateT),evalStateT,get,put)
import Rdkafka.Client.Types (Consumer)
import Control.Monad (forever)

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
import qualified Rdkafka.Client.Consumer as Consumer
import qualified Rdkafka.Client.Configuration as Configuration
import qualified System.IO as IO

main :: IO ()
main = do
  () <- when (not rtsSupportsBoundThreads) (fail "threaded runtime required")
  (broker,topic,group) <- getArgs >>= \case
    [broker,topic,group] -> pure
      (MCS.fromLatinString broker,MCS.fromLatinString topic,MCS.fromLatinString group)
    _ -> fail "Please provide a broker and a topic as arguments"
  version <- K.versionByteArray
  putStr ("librdkafka version: ")
  Bytes.hPut IO.stdout (Bytes.fromByteArray version)
  putStrLn ("\nBroker: " ++ show broker)
  putStrLn ("Topic: " ++ show topic)
  rk <- either throwBytesIO pure =<< initialize broker group
  either throwIO pure =<< Consumer.subscribe rk topic
  either throwIO pure =<< Consumer.poll rk
  forever $ Consumer.poll rk >>= \case
    Left e -> putStrLn ("Error code " ++ show e)
    Right msg -> do
      bytes <- Message.peekPayload msg
      len <- Message.peekLength msg
      IO.hPutBuf IO.stdout bytes (fromIntegral len)
      IO.hPutChar IO.stdout '\n'
      K.messageDestroy msg

initialize ::
     ManagedCString
  -> ManagedCString
  -> IO (Either Bytes Consumer)
initialize !broker !group = Configuration.consumer $ do
  Configuration.set "bootstrap.servers" broker
  Configuration.set "log_level" "6"
  Configuration.set "group.id" group
  Configuration.set "auto.offset.reset" "latest"

throwBytesIO :: Bytes -> IO a
throwBytesIO b = do
  Bytes.hPut IO.stderr b
  fail "dieing"

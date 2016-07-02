module Main where


import Dropp.Http
import Dropp.HTML
import Dropp.DataTypes
import qualified Data.ByteString as By
import Data.Yaml (decode)
import System.Environment (getArgs)
import Data.Maybe (fromJust)
import Data.Text.Internal (Text)
import Data.Text.Lazy.Encoding (decodeUtf8)
import Data.Text.Lazy (toStrict)
import System.IO (stdout)
import Data.Text
  ( pack
  , unpack)

import Network.HTTP.Conduit
  ( newManager
  , tlsManagerSettings)

import Data.Time.Clock
  ( UTCTime
  , getCurrentTime)

import Data.Time.LocalTime
  ( TimeZone (TimeZone)
  , utcToLocalTime)

import Data.Time.Format
  ( formatTime
  , defaultTimeLocale)

import Network.AWS
  ( Region (Ireland)
  , Credentials (Discover)
  , LogLevel (Debug)
  , newEnv
  , newLogger
  , envLogger
  , send
  , runAWS
  , runResourceT)

import qualified Network.AWS.SES as SES
import Network.AWS.SES
  ( SendEmail
  , dToAddresses
  , cData
  , bHTML
  , destination
  , body)

import Control.Lens
  ( (&)
  , (.~))




main :: IO ()
main = do

    -- Read configuration file.
    [filePath] <- getArgs
    vars <- decode <$> By.readFile filePath :: IO (Maybe DroppEnv)
    let droppEnv = fromJust vars

    -- Create connection manager
    mgr <- newManager tlsManagerSettings

    -- Fetch pages urls from DB.
    dbItems <- fromJust <$> getItems mgr (dbItemsUrl droppEnv)

    -- Fetch all pages listed in the DB table.
    items <- mapM (getItemUpdate mgr) dbItems

    -- Get timestamp.
    utcTime <- getCurrentTime

    -- Generate email subject.
    let subText = pack $ "Availability " ++ formatTimeStamp utcTime

    -- Generate email HTML body.
    let bodyText = toStrict $ decodeUtf8 $ formatOutput items

    -- Generate full report email.
    let email = makeEmail droppEnv subText bodyText

    if sendEmail droppEnv
      then do

        -- Generate AWS environment and insantiate logger.
        env <- newEnv Ireland Discover
        logger <- newLogger Debug stdout

        -- Send report email.
        _ <- runResourceT . runAWS
            (env & envLogger .~ logger)
            $ send email

        return ()

      else
        writeFile (emailDumpFilePath droppEnv) (unpack bodyText)



-- | Generate a string containing a local timestamp in a human readable format.
formatTimeStamp :: UTCTime -> String
formatTimeStamp utcTime = formatTime defaultTimeLocale format cestTime
  where
    cestTime = utcToLocalTime cest utcTime
    cest = TimeZone 120 True "CEST"
    format = "%a %d/%m/%Y %R"

-- ------------------------------------------------------------------------- --
--              AWS SES SERVICE
-- ------------------------------------------------------------------------- --


-- | Generate a list of emails to be sent.
makeEmail :: DroppEnv -> Text -> Text -> SendEmail
makeEmail droppEnv subText payload = SES.sendEmail (sender droppEnv) dest msg
  where
    dest = destination & dToAddresses .~ recipients droppEnv
    msg = SES.message subject body'
    subject = SES.content "" & cData .~ subText
    body' = body & bHTML .~ Just (SES.content payload)

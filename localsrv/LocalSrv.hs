import Network.Wai
import Network.Wai.Handler.Warp
import Network.HTTP.Types
  ( status200
  , status404)

import Blaze.ByteString.Builder (copyByteString)
import qualified Data.ByteString.UTF8 as BU
import Data.Monoid


main = do
    let port = 3000
    putStrLn $ "Listening on port " ++ show port
    run port app


app req respond =
    respond
      $ case pathInfo req of
        ["bangOK.html"] -> bangOK
        ["bangWrong.html"] -> bangWrong
        x -> index x


bangOK =
    responseBuilder
    status200
    [("Content-Type", "text/html")]
    $ mconcat
    $ map copyByteString
    [ "<!DOCTYPE html>"
    , "<html><head><title>Title</title></head>"
    , "<body>"
    , "<div class=\"status\">"
    , "In stock, usually dispatched in 1 business day"
    , "</div>"
    , "</body>"
    , "</html>"]


bangWrong =
    responseBuilder
    status404
    [("Content-Type", "text/html")]
    $ mconcat
    $ map copyByteString ["<p>wong!</p>"]


index x =
    responseBuilder
    status200
    [("Content-Type", "text/html")]
    $ mconcat
    $ map copyByteString
    [ "<p>Hello from "
    , BU.fromString $ show x
    , "!</p>"
    , "<p><a href='/yay'>yay</a></p>\n" ]

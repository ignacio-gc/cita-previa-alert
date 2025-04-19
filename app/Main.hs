{-# LANGUAGE OverloadedStrings #-}

import Data.Text qualified as T
import qualified Data.Text.IO as TIO
import qualified Data.Text.Lazy as TL
import Text.HTML.Scalpel
import Data.List (find)
import Main.Utf8 (withUtf8)
import Network.Mail.SMTP 
import Network.Socket 
import Text.HTML.TagSoup
import Control.Exception (throwIO)

-- Email config --

data EmailConfig = EmailConfig
  { emailFrom :: Address,
    emailTo :: [Address],
    emailSubject :: T.Text,
    smtpServer :: String,
    smtpPort :: PortNumber,
    smtpUsername :: String,
    smtpPassword :: String,
    host :: String
  }

emailConfig :: EmailConfig
emailConfig =
  EmailConfig
    { emailFrom = Address Nothing "",
      emailTo = [Address (Just "Name") ""],
      emailSubject = "Turno disponible para pasaporte",
      smtpServer = "smtp.gmail.com",
      smtpPort = 465,
      smtpUsername = "",
      smtpPassword = "",
      host = "smtp.gmail.com"
    }

getTagTextOrFail :: String -> [Tag T.Text] -> IO T.Text
getTagTextOrFail tagName tags =
  case dropWhile (~/= TagOpen (T.pack tagName) []) tags of
    (_ : TagText txt : _) -> return txt
    _ -> throwIO $ userError $ "Missing tag: <" ++ tagName ++ ">"

getEmailConfigs :: IO [Tag T.Text]
getEmailConfigs = do
  xml <- TIO.readFile "../config/configs.xml"
  let tags = parseTags xml
  return tags

-- END Email config --

sendNotificationEmail :: T.Text -> T.Text -> IO ()
sendNotificationEmail date link = do
  let subject = "Notificación de turnos"
  let body = (T.concat ["Se encontró un turno disponible:\n\n", date, link])
  let htmlForMail = htmlPart $ TL.fromStrict $ T.concat ["<p>Se encontró un turno disponible:</p><ul><li><b>Fecha:</b> ", date, "</li><li><b>Link:</b> ", link, "</li></ul>"]
  -- Complete emailConfig with data from config file ---
  confs <- getEmailConfigs
  mail <- getTagTextOrFail "mail-addr" confs
  pass <- getTagTextOrFail "mail-pass" confs
  name <- getTagTextOrFail "name" confs
  let emailConfigWithMailAndPass =
        emailConfig
          { emailFrom = Address Nothing mail,
            emailTo = [Address (Just name) mail],
            smtpUsername = T.unpack mail,
            smtpPassword = T.unpack pass
          }
  --- --- ---
  let mail = simpleMail (emailFrom emailConfigWithMailAndPass) (emailTo emailConfigWithMailAndPass) [] [] subject [plainTextPart (TL.fromStrict body), htmlForMail]
  sendMailWithLoginTLS' (host emailConfigWithMailAndPass) (smtpPort emailConfigWithMailAndPass) (smtpUsername emailConfigWithMailAndPass) (smtpPassword emailConfigWithMailAndPass) mail

findDateAndLink :: [(Int, T.Text)] -> Maybe (T.Text, T.Text)
findDateAndLink lst = do
  let date = find (\i -> fst i == 2) lst
  let link = find (\i -> fst i == 3) lst
  case (date, link) of
    (Just date', Just link') -> 
      if not $ "fecha por confirmar" `T.isInfixOf` (snd date')
        then case (scrapeStringLike (snd link') $ attr "href" "a") of
               Just href -> Just (snd date', href) 
               Nothing -> Nothing
        else Nothing
    _ -> Nothing
    
-- Scrapers --

scraperTrRenovacionPasaporte :: Scraper T.Text (Maybe T.Text)
scraperTrRenovacionPasaporte = chroot "tbody" $ do
  trs <- htmls "tr"
  let tr = find (\date' -> "renovación y primera vez" `T.isInfixOf` date') trs
  return tr

scraperPosAndHtmlInsideTr :: Scraper T.Text [(Int, T.Text)]
scraperPosAndHtmlInsideTr = chroots "td" $ do
  pos <- position
  txt <- html "td"
  return (pos, txt)

------------------------------------------------------------------------------------------------------------------------------- 

main :: IO ()
main = withUtf8 $ do
  let url = "https://www.cgeonline.com.ar/informacion/apertura-de-citas.html"
  trResult <- scrapeURL url scraperTrRenovacionPasaporte
  case trResult of
    Just (Just tr) -> do
      let trNodesWithPosition = scrapeStringLike tr scraperPosAndHtmlInsideTr
      case trNodesWithPosition of
        Just posAndNodesList ->
          case findDateAndLink posAndNodesList of
            Just dateAndLink -> sendNotificationEmail (fst dateAndLink) (snd dateAndLink)
            Nothing -> TIO.putStrLn "No se encontró un turno disponible" 
        _ -> TIO.putStrLn "Se encontró la parte correspondiente a pasaportes pero no se pudo procesar el contenido"
    _ -> TIO.putStrLn "No encontró el html correspondiente a renovación y primera vez de pasaporte"

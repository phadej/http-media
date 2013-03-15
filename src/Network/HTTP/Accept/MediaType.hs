{-# LANGUAGE OverloadedStrings #-}

------------------------------------------------------------------------------
-- | Defines the media type types and functions.
module Network.HTTP.Accept.MediaType
    (
      -- * Type and creation
      MediaType
    , Parameters
    , (//)
    , (/:)
    , parse
    , anything

      -- * Querying
    , mainType
    , subType
    , parameters
    , (/?)
    , (/.)
    , matches
    ) where

------------------------------------------------------------------------------
import           Control.Monad (guard)

import           Data.ByteString (ByteString, split)
import qualified Data.ByteString as BS
import           Data.ByteString.UTF8 (toString)
import           Data.Map (Map, empty, foldrWithKey, insert)
import qualified Data.Map as Map
import           Data.Maybe (fromMaybe)
import           Data.String (IsString (..))

------------------------------------------------------------------------------
import           Network.HTTP.Accept.Match hiding (matches)
import qualified Network.HTTP.Accept.Match as Match
import           Network.HTTP.Accept.Utils


------------------------------------------------------------------------------
-- | An HTTP media type, consisting of the type, subtype, and parameters.
data MediaType = MediaType
    { -- | The main type of the MediaType.
      mainType   :: ByteString
      -- | The sub type of the MediaType.
    , subType    :: ByteString
      -- | The parameters of the MediaType.
    , parameters :: Parameters
    } deriving (Eq)

instance Show MediaType where
    show (MediaType a b p) =
        foldrWithKey f (toString a ++ '/' : toString b) p
      where
        f k v = (++ ';' : toString k ++ '=' : toString v)

instance Match MediaType where
    matches a b
        | mainType b == "*" = params
        | subType b == "*"  = mainType a == mainType b && params
        | otherwise         = main && sub && params
      where
        main = mainType a == mainType b
        sub = subType a == subType b
        params = Map.null (parameters b) || parameters a == parameters b

    moreSpecificThan a b
        | mainType a == "*" = anyB && params
        | subType a == "*"  = anyB || subB && params
        | otherwise         = anyB || subB || params
      where
        anyB = mainType b == "*"
        subB = subType b == "*"
        params = not (Map.null $ parameters a) && Map.null (parameters b)

instance IsString MediaType where
    fromString s = flip fromMaybe (parse $ fromString s) $
        error ("Invalid MediaType literal: " ++ s)

instance IsString [MediaType] where
    fromString s = map (fromString . reverse) $ csplit [] s
      where
        csplit a  (',' : r) = a : csplit [] r
        csplit a  (x   : r) = csplit (x : a) r
        csplit a  _         = [a]


------------------------------------------------------------------------------
-- | 'MediaType' parameters.
type Parameters = Map ByteString ByteString


------------------------------------------------------------------------------
-- | Builds a 'MediaType' without parameters.
(//) :: ByteString -> ByteString -> MediaType
a // b = MediaType (trimBS a) (trimBS b) empty


------------------------------------------------------------------------------
-- | Adds a parameter to a 'MediaType'.
(/:) :: MediaType -> (ByteString, ByteString) -> MediaType
(MediaType a b p) /: (k, v) = MediaType a b $ insert k v p


------------------------------------------------------------------------------
-- | Evaluates if a 'MediaType' has a parameter of the given name.
(/?) :: MediaType -> ByteString -> Bool
(MediaType _ _ p) /? k = Map.member k p


------------------------------------------------------------------------------
-- | Retrieves a parameter from a 'MediaType'.
(/.) :: MediaType -> ByteString -> Maybe ByteString
(MediaType _ _ p) /. k = Map.lookup k p


------------------------------------------------------------------------------
-- | A MediaType that matches anything.
anything :: MediaType
anything = "*" // "*"


------------------------------------------------------------------------------
-- | Parses a MIME string into a 'MediaType'.
parse :: ByteString -> Maybe MediaType
parse bs = do
    let pieces = split semi bs
    guard $ not (null pieces)
    let (m : ps) = pieces
        (a, b)   = breakByte slash m
    guard $ BS.elem slash m && (a /= "*" || b == "*")
    return $ foldr (flip (/:) . breakByte equal) (a // b) ps


------------------------------------------------------------------------------
-- | Evaluates if the left argument matches the right one.
--
-- The order of the arguments is important: if the right argument is more
-- specific than the left, they will not be considered to match. The
-- following evalutes to 'False'.
--
-- > matches ("text" // "*") ("text" // "plain")
matches :: MediaType -> MediaType -> Bool
matches = Match.matches


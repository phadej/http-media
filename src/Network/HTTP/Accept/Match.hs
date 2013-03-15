------------------------------------------------------------------------------
-- | Defines the 'Match' type class, designed to unify types on the
-- matching functions in the Accept module.
module Network.HTTP.Accept.Match
    (
      Match (..)
    , mostSpecific
    ) where

------------------------------------------------------------------------------
import Data.ByteString


------------------------------------------------------------------------------
-- | Defines methods for a type whose values can be matched against each
-- other in terms of an Accept value.
--
-- This allows functions to work on both the standard Accept header and
-- others such as Accept-Language that still may use quality values.
class Match a where
    -- | Evaluates whether either the left argument matches the right one.
    matches :: a -> a -> Bool
    -- | Evaluates whether the left argument is more specific than the right.
    moreSpecificThan :: a -> a -> Bool
    moreSpecificThan _ _ = False

instance Match ByteString where
    matches = (==)


------------------------------------------------------------------------------
-- | Evaluates to whichever argument is more specific, choosing the left
mostSpecific :: Match a => a -> a -> a
mostSpecific a b
    | b `moreSpecificThan` a = b
    | otherwise              = a


{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE Rank2Types          #-}
{-# LANGUAGE ScopedTypeVariables #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.SBV.Tools.Strings
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
--
-- A collection of string/character utilities, useful when working
-- with symbolic strings. To the extent possible, the functions
-- in this module follow those of "Data.Char", so importing
-- qualified is the recommended workflow.
-----------------------------------------------------------------------------

module Data.SBV.Tools.Strings (
        -- * The symbolic "character"
        SChar
        -- * Conversion to/from SWord8
        , ord, chr
        -- * Deconstructing/Reconstructing
        , strHead, strTail, charToStr, strToCharAt, implode
        -- * Recognizers
        , isControl, isSpace, isLower, isUpper, isAlpha, isAlphaNum, isPrint, isDigit, isOctDigit, isHexDigit, isLetter, isPunctuation
        -- * Regular Expressions
        -- ** White space
        , reNewline, reWhitespace, reWhiteSpaceNoNewLine
        -- ** Separators
        , reTab, rePunctuation
        -- ** Digits
        , reDigit, reOctDigit, reHexDigit
        -- ** Numbers
        , reDecimal, reOctal, reHexadecimal
        -- ** Identifiers
        , reIdentifier
        ) where

import Data.SBV.Core.Data
import Data.SBV.Core.Model
import Data.SBV.Core.String

import qualified Data.Char as C
import Data.List (genericLength, genericIndex)

-- For doctest use only
--
-- $setup
-- >>> import Data.SBV.Provers.Prover (prove)
-- >>> import Data.SBV.Utils.Boolean  ((&&&), (==>), bnot)

-- | The symbolic "character." Note that, as far as SBV's symbolic strings are concerned, a character
-- is essentially an 8-bit unsigned value, and hence is equivalent to the type 'SWord8'. Technically
-- speaking, this corresponds to the ISO-8859-1 (Latin-1) character set. A Haskell 'Char', on the other
-- hand, is a unicode beast; so there isn't a 1-1 correspondence between a Haskell character and an
-- SBV character. This limitation is due to the SMT-solvers only supporting this particular subset,
-- which may be relaxed in future versions.
type SChar = SWord8

-- | The 'ord' of a character. Note that this is essentially identity function due to
-- our representation, appropriately typed to have any numeric type.
ord :: SIntegral a => SChar -> SBV a
ord = sFromIntegral

-- | Conversion from a value to a character. If the value is not in the range
-- 0..255, then the output is underspecified.
--
-- >>> prove $ \x -> (0 .<= x &&& x .< (255 :: SInteger)) ==> ord (chr x) .== x
-- Q.E.D.
-- >>> prove $ \x -> chr ((ord x) :: SInteger) .== x
-- Q.E.D.
chr :: SIntegral a => SBV a -> SChar
chr = sFromIntegral

-- | @`strHead`@ returns the head of a string. Unspecified if the string is empty.
--
-- >>> prove $ \c -> strHead (charToStr c) .== c
-- Q.E.D.
strHead :: SString -> SWord8
strHead = (`strToCharAt` 0)

-- | @`strTail`@ returns the tail of a string. Unspecified if the string is empty.
--
-- >>> prove $ \h s -> strTail (charToStr h .++ s) .== s
-- Q.E.D.
-- >>> prove $ \s -> strLen s .> 0 ==> strLen (strTail s) .== strLen s - 1
-- Q.E.D.
-- >>> prove $ \s -> bnot (strNull s) ==> charToStr (strHead s) .++ strTail s .== s
-- Q.E.D.
strTail :: SString -> SString
strTail s
 | Just (_:cs) <- unliteral s
 = literal cs
 | True
 = strSubstr s 1 (strLen s - 1)


-- | @`charToStr` c@ is the string of length 1 that contains the only character
-- whose value is the 8-bit value @c@.
--
-- >>> :set -XOverloadedStrings
-- >>> prove $ \c -> c .== 65 ==> charToStr c .== "A"
-- Q.E.D.
-- >>> prove $ \c -> strLen (charToStr c) .== 1
-- Q.E.D.
charToStr :: SWord8 -> SString
charToStr = lift1 StrUnit (Just $ \cv -> [C.chr (fromIntegral cv)])

-- | @`strToCharAt` s i@ is the 8-bit value stored at location @i@. Unspecified if
-- index is out of bounds.
--
-- >>> :set -XOverloadedStrings
-- >>> prove $ \i -> i .>= 0 &&& i .<= 4 ==> "AAAAA" `strToCharAt` i .== 65
-- Q.E.D.
-- >>> prove $ \s i c -> s `strToCharAt` i .== c ==> strIndexOf s (charToStr c) .<= i
-- Q.E.D.
strToCharAt :: SString -> SInteger -> SWord8
strToCharAt s i
  | Just cs <- unliteral s, Just ci <- unliteral i, ci >= 0, ci < genericLength cs, let c = C.ord (cs `genericIndex` ci), c >= 0, c < 256
  = literal (fromIntegral c)
  | True
  = SBV (SVal w8 (Right (cache (y (s `strAt` i)))))
  where w8      = KBounded False 8
        -- This is tricker than it needs to be, but necessary since there's
        -- no SMTLib function to extract the character from a string. Instead,
        -- we form a singleton string, and assert that it is equivalent to
        -- the extracted value. See <http://github.com/Z3Prover/z3/issues/1302>
        y si st = do c <- internalVariable st w8
                     cs <- newExpr st KString (SBVApp (StrOp StrUnit) [c])
                     let csSBV = SBV (SVal KString (Right (cache (\_ -> return cs))))
                     internalConstraint st Nothing $ unSBV $ csSBV .== si
                     return c

-- | @`implode` cs@ is the string of length @|cs|@ containing precisely those
-- characters. Note that there is no corresponding function @explode@, since
-- we wouldn't know the length of a symbolic string.
--
-- >>> prove $ \c1 c2 c3 -> strLen (implode [c1, c2, c3]) .== 3
-- Q.E.D.
-- >>> prove $ \c1 c2 c3 -> map (strToCharAt (implode [c1, c2, c3])) (map literal [0 .. 2]) .== [c1, c2, c3]
-- Q.E.D.
implode :: [SChar] -> SString
implode = foldr ((.++) . charToStr) ""

isControl             :: a
isControl             = error "isControl"

isSpace               :: a
isSpace               = error "isSpace"

isLower               :: a
isLower               = error "isLower"

isUpper               :: a
isUpper               = error "isUpper"

isAlpha               :: a
isAlpha               = error "isAlpha"

isAlphaNum            :: a
isAlphaNum            = error "isAlphaNum"

isPrint               :: a
isPrint               = error "isPrint"

isDigit               :: a
isDigit               = error "isDigit"

isOctDigit            :: a
isOctDigit            = error "isOctDigit"

isHexDigit            :: a
isHexDigit            = error "isHexDigit"

isLetter              :: a
isLetter              = error "isLetter"

isPunctuation         :: a
isPunctuation         = error "isPunctuation"

reNewline             :: a
reNewline             = error "reNewline"

reWhitespace          :: a
reWhitespace          = error "reWhitespace"

reWhiteSpaceNoNewLine :: a
reWhiteSpaceNoNewLine = error "reWhiteSpaceNoNewLine"

reTab                 :: a
reTab                 = error "reTab"

rePunctuation         :: a
rePunctuation         = error "rePunctuation"

reDigit               :: a
reDigit               = error "reDigit"

reOctDigit            :: a
reOctDigit            = error "reOctDigit"

reHexDigit            :: a
reHexDigit            = error "reHexDigit"

reDecimal             :: a
reDecimal             = error "reDecimal"

reOctal               :: a
reOctal               = error "reOctal"

reHexadecimal         :: a
reHexadecimal         = error "reHexadecimal"

reIdentifier          :: a
reIdentifier          = error "reIdentifier"

-- | Lift a unary operator over strings.
lift1 :: forall a b. (SymWord a, SymWord b) => StrOp -> Maybe (a -> b) -> SBV a -> SBV b
lift1 w mbOp a
  | Just cv <- concEval1 mbOp a
  = cv
  | True
  = SBV $ SVal k $ Right $ cache r
  where k = kindOf (undefined :: b)
        r st = do swa <- sbvToSW st a
                  newExpr st k (SBVApp (StrOp w) [swa])

-- | Concrete evaluation for unary ops
concEval1 :: (SymWord a, SymWord b) => Maybe (a -> b) -> SBV a -> Maybe (SBV b)
concEval1 mbOp a = literal <$> (mbOp <*> unliteral a)
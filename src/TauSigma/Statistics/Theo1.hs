{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Theo1 stability statistic.  See:
--
-- * http://tf.nist.gov/timefreq/general/pdf/1990.pdf
-- * http://tf.nist.gov/general/pdf/2220.pdf
module TauSigma.Statistics.Theo1
       ( Tau0

       , isTheo1Tau
         
       , theo1var
       , theo1dev
       , theo1vars
       , theo1devs

       , theoBRvars
       , theoBRdevs
       , toTheoBRvars
       , toTheoBRdevs
       ) where

import Data.Vector.Generic (Vector, (!))
import qualified Data.Vector.Generic as V

import Data.IntMap (IntMap)
import qualified Data.IntMap as IntMap

import TauSigma.Statistics.Allan (avars)
import TauSigma.Statistics.Util


-- | Theo1 is only defined for certain sampling intervals.
isTheo1Tau :: Int -> Int -> Bool
isTheo1Tau m size = even m && 10 <= m && m <= size - 1

theo1var :: (Fractional a, Vector v a) => Tau0 -> Int -> v a -> Maybe a
{-# INLINABLE theo1var #-}
theo1var tau0 m xs
  | m `isTheo1Tau` V.length xs =
      Just (unsafeTheo1var tau0 m xs)
  | otherwise = Nothing

theo1dev :: (Floating a, Vector v a) => Tau0 -> Int -> v a -> Maybe a
{-# INLINABLE theo1dev #-}
theo1dev tau0 m xs = fmap sqrt (theo1var tau0 m xs)

theo1vars :: (Fractional a, Vector v a) => Tau0 -> v a -> IntMap a
{-# INLINABLE theo1vars #-}
theo1vars tau0 xs = IntMap.fromList (map go taus)
  where size = V.length xs
        taus = filter (flip isTheo1Tau size) [1 .. 3 * (size `div` 4)]
        go m = (m, unsafeTheo1var tau0 m xs)

theo1devs :: (Floating a, Vector v a) => Tau0 -> v a -> IntMap a
{-# INLINABLE theo1devs #-}
theo1devs tau0 xs = IntMap.map sqrt (theo1vars tau0 xs)


-- | This is a worse than a partial function: it's a function that
-- produces incorrect results for some of its arguments.  Stick to
-- 'theo1vars' unless you really know what you're doing.
unsafeTheo1var :: (Fractional a, Vector v a) => Tau0 -> Int -> v a -> a
{-# INLINABLE unsafeTheo1var #-}
unsafeTheo1var tau0 m xs = outer / (0.75 * fromIntegral divisor)
  where divisor :: Integer
        divisor = (len - m') * (m' * tau0')^2
          where m' = fromIntegral m
                tau0' = fromIntegral tau0
                len = fromIntegral (V.length xs)
        outer = summation 0 (V.length xs - m) middle
          where middle i = summation 0 (m `div` 2) inner
                  where inner d = term^2 / fromIntegral (halfM - d)
                          where halfM = m `div` 2
                                term = (xs!i - xs!(i - d + halfM))
                                     + (xs!(i+m) -xs!(i + d + halfM))

unsafeTheo1dev :: (Floating a, Vector v a) => Tau0 -> Int -> v a -> a
{-# INLINABLE unsafeTheo1dev #-}
unsafeTheo1dev tau0 m xs = sqrt (unsafeTheo1var tau0 m xs)

-- | Bias-reduced Theo1 variance.  This computes 'avars' and
-- 'theo1vars', so if you're doing that anyway you may wish to use
-- 'toTheoBRvars' which reuses the memoized results of those two.
theoBRvars :: (RealFrac a, Vector v a) => Tau0 -> v a -> IntMap a
{-# INLINABLE theoBRvars #-}
theoBRvars tau0 xs = toTheoBRvars (V.length xs) allans theo1s
  where allans = avars tau0 xs
        theo1s = theo1vars tau0 xs

theoBRdevs :: (Floating a, RealFrac a, Vector v a) => Tau0 -> v a -> IntMap a
{-# INLINABLE theoBRdevs #-}
theoBRdevs tau0 xs = IntMap.map sqrt (theoBRvars tau0 xs)


toTheoBRvars
  :: forall v a. (RealFrac a) =>
     Int        -- ^ The length of the phase point data set
  -> IntMap a   -- ^ The 'avars' result
  -> IntMap a   -- ^ The 'theo1vars' result
  -> IntMap a
{-# INLINABLE toTheoBRvars #-}
toTheoBRvars size allans theo1s = IntMap.map go theo1s
  where go :: a -> a
        go theo1 = (ratio * theo1) / fromIntegral (n+1)

        n :: Int
        -- From Howe & Tasset:
        n = floor (((0.1 * fromIntegral size) / 3) - 3)
{- Riley has this instead:

        n = floor (fromIntegral size / 6 - 3)

   Which is way slower and for some tests produces Maybe.fromJust: Nothing
   errors in the ratio code below.
-}

        ratio :: a
        ratio = summation 0 (n+1) term
          where term :: Int -> a
                term i = theAvar / theTheo1
                  where unsafe :: Int -> IntMap a -> a
                        unsafe k m = case IntMap.lookup k m of
                                      Just v -> v
                                      _ -> error "toTheoBRvars: bad index"
                        theAvar :: a
                        theAvar  = unsafe (9 + 3*i) allans
                        theTheo1 :: a
                        theTheo1 = unsafe (12 + 4*i) theo1s

toTheoBRdevs
  :: (Floating a, RealFrac a) =>
     Int        -- ^ The length of the phase point data set
  -> IntMap a   -- ^ The 'avars' result
  -> IntMap a   -- ^ The 'theo1vars' result
  -> IntMap a
{-# INLINABLE toTheoBRdevs #-}
toTheoBRdevs size allans theo1s =
  IntMap.map sqrt (toTheoBRvars size allans theo1s)

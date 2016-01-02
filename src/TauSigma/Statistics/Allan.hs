
-- | Allan Variance and other related frequency stability statistics.
--
-- See: http://tf.nist.gov/general/pdf/2220.pdf
--
module TauSigma.Statistics.Allan
       ( Tau0
       , avar
       , avars
       , adev
       , adevs
       ) where

import Data.IntMap.Lazy (IntMap)
import qualified Data.IntMap.Lazy as IntMap
import Data.Vector.Generic (Vector, (!))
import qualified Data.Vector.Generic as V

import TauSigma.Statistics.Util


avar :: (Fractional a, Vector v a) => Tau0 -> Int -> v a -> a
avar tau0 m xs = sumsq / fromIntegral divisor
  where divisor = 2 * m^2 * tau0^2 * (V.length xs - 2*m)
        sumsq = sumGen (V.length xs - 2*m) step
          where step i = (xs!(i+2*m) - 2*(xs!(i+m)) + xs!i)^2

adev :: (Floating a, Vector v a) => Tau0 -> Int -> v a -> a
adev tau0 m xs = sqrt (avar tau0 m xs)

avars :: (RealFrac a, Vector v a) => Tau0 -> v a -> IntMap a
avars tau0 xs = IntMap.fromList (map step [1..maxTaus])
  where step m = (m, avar tau0 m xs)
        maxTaus = (V.length xs - 1) `div` 2
                    
adevs :: (RealFloat a, Vector v a) => Tau0 -> v a -> IntMap a
adevs tau0 xs = IntMap.map sqrt (avars tau0 xs)



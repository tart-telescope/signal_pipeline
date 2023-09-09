{-# LANGUAGE LambdaCase    #-}
{-# LANGUAGE TupleSections #-}

module Main where

import           Data.Complex
import           Text.Printf

type Z = Int
type R = Double

main :: IO ()
main  = do
  let zs  = [ r :+ i | r <- [-1, 1], i <- [-1, 1] ] :: [Complex R]
      vs  = (,) <$> zs <*> zs
      fi :: R -> Z
      fi  = round -- fromIntegral
      go :: Complex R -> Complex R -> IO ()
      go x y =
        let re = realPart vx
            im = imagPart vx
            vx = fi <$> x * conjugate y
            xs = show (fi <$> x)
            ys = show (fi <$> y)
        in  printf "Z[a] = %s \t Z[b] = %s \t Re[a][b] = %d \t Im[a][b] = %d\n" xs ys re im

      z3  = [ r :+ i | r <- [-3,-1,1,3], i <- [-3,-1,1,3] ] :: [Complex R]
      v3  = (,) <$> z3 <*> z3
      t3 :: Complex R -> Complex R -> IO ()
      t3 x y =
        let re = show $ realPart vx
            im = show $ imagPart vx

            bit = \case
              -3 -> "00"
              -1 -> "01"
              1  -> "10"
              3  -> "11"

            vx = fi <$> x * conjugate y

            xr = bit $ realPart x
            xi = bit $ imagPart x

            yr = bit $ realPart y
            yi = bit $ imagPart y

        in  printf "| %s | %s | %s | %s | | %s | %s |\n" xr xi yr yi re im

{--}
      z7  = [ r :+ i | r <- [-7,-5..7], i <- [-7,-5..7] ] :: [Complex R]
      v7  = (,) <$> z7 <*> z7
      t7 :: Complex R -> Complex R -> IO ()
      t7 x y =
        let re = show $ realPart vx
            im = show $ imagPart vx

            bit b = go ((b+7) / 2) where
              go :: R -> String
              go  = printf "%03b" . fi

            vx = fi <$> x * conjugate y

            xr = bit $ realPart x
            xi = bit $ imagPart x

            yr = bit $ realPart y
            yi = bit $ imagPart y

        in  printf "| %s | %s | %s | %s | | %s | %s |\n" xr xi yr yi re im
--}

      tt :: Complex R -> Complex R -> IO ()
      tt x y =
        let re = vis $ realPart vx
            im = vis $ imagPart vx
            vis b
              | b < 0 = " 0b110 | -2 "
              | b > 0 = " 0b010 |  2 "
              | otherwise = " 0b000 |  0 "
            bit b
              | b < 0 = "0"
              | b > 0 = "1"
              | otherwise = error "Oh noes!"
            vx = fi <$> x * conjugate y

            xr = bit $ realPart x
            xi = bit $ imagPart x

            yr = bit $ realPart y
            yi = bit $ imagPart y

        in  printf "| %s | %s | %s | %s | | %s | %s |\n" xr xi yr yi re im

  uncurry tt `mapM_` vs
--   uncurry t3 `mapM_` v3
--   uncurry t7 `mapM_` v7

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

      tt :: Complex R -> Complex R -> IO ()
      tt x y =
        let re = vis $ realPart vx
            im = vis $ imagPart vx
            vis b
              | b < 0 = "-2 | 0b110 "
              | b > 0 = " 2 | 0b010 "
              | otherwise = " 0 | 0b000 "
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

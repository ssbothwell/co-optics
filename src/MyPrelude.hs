module MyPrelude
  ( module P
  , module C
  , ifThenElse
  , type (+)
  , type (×)
  , module T
  , (&)
  )
  where

import Prelude as P hiding
  ( Applicative(..)
  , zip
  , id
  , (.)
  )

import Control.Category as C

import Debug.Trace as T
import Data.Function ((&))

ifThenElse :: Bool -> a -> a -> a
ifThenElse b x y = if b then x else y

type x + y = Either x y
infixr 6 +

type x × y = (x, y)
infixr 7 ×

{-# LANGUAGE LambdaCase, ViewPatterns, DeriveGeneric #-}
module Examples.Biparsing.Common where

import MyPrelude

import GHC.Natural

import Data.Profunctor

import Data.Digit

import Control.Monad.State (StateT(..), MonadState(..))
import Control.Monad.Writer (WriterT(..), MonadWriter(..))

import Profunctor.Joker
import Profunctor.Kleisli
import Profunctor.Product
import Profunctor.Mux
import Profunctor.Demux
import Profunctor.Muxable

import Monoidal.Applicative
import Monoidal.Alternative

import Optics

type Parser    f   = Joker (StateT String f)
type Printer   f   = Kleisli (WriterT String f)
type Biparser  f   = Product (Parser f) (Printer f)
type Biparser' f x = Biparser f x x

biparser :: StateT String f o -> (i -> WriterT String f o) -> Biparser f i o
biparser x y = Pair (Joker x) (Kleisli y)

biparse :: Biparser f i o -> String -> f (o, String)
biparse = runStateT . runJoker . pfst

biparse_ :: Functor f => Biparser f i o -> String -> f o
biparse_ bp = fmap fst . biparse bp

biprint :: Biparser f i o -> i -> f (o, String)
biprint = (runWriterT .) . runKleisli . psnd

biprint_ :: Functor f => Biparser f i o -> i -> f String
biprint_ bp = fmap snd . biprint bp

anychar :: Biparser' Maybe Char
anychar = biparser r w
  where
  r = get >>= \case { [] -> empty; (c : xs) -> c <$ put xs }
  w c = c <$ tell [c]

satisfy :: (a -> Bool) -> Biparser' Maybe a -> Biparser' Maybe a
satisfy p = re (predicate p)

char :: Char -> Biparser' Maybe Char
char c = re (exactly c) anychar

besides :: String -> Biparser' Maybe Char
besides s = satisfy (not . (`elem` s)) $ anychar

string :: String -> Biparser' Maybe String
string s = bundle $ char <$> s

token :: String -> x -> Biparser Maybe a x
token s x = dimap (const s) (const x) $ string s

token_ :: String -> Biparser Maybe a ()
token_ s = token s ()

trivial :: Biparser Maybe a ()
trivial = start

eof :: Biparser Maybe a ()
eof = re right' $ anychar \/ trivial

perhaps :: Biparser' Maybe x -> Biparser' Maybe (Maybe x)
perhaps p = maybeToEither . symmE $ p \/ trivial

sign :: Biparser' Maybe Bool
sign = perhaps (char '-') & dimap sign2char char2sign
  where
  sign2char True = Nothing
  sign2char False = Just '-'

  char2sign (Just _) = False
  char2sign Nothing = True

digit :: Biparser' Maybe DecDigit
digit = re (convert charDecimal) $ anychar

nat :: Biparser' Maybe Natural
nat = re digitsAsNatural $ re _Just $ re listToNonEmpty $ many digit

int :: Biparser' Maybe Int
int = do
  s <- sign & lmap (\i -> i >= 0)
  n <- nat & lmap (intToNatural . abs)
  let i = naturalToInt n
  pure $ if s
    then i
    else -i

hexDigit :: Biparser' Maybe HeXDigit
hexDigit = re (convert charHeXaDeCiMaL) anychar

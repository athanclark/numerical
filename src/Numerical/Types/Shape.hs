{-# LANGUAGE PolyKinds   #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Numerical.Types.Shape where

import Control.Applicative
import Data.Foldable 
import Data.Monoid
import Data.Functor
import Numerical.Types.Nat 
import Prelude (seq, ($!),($),Show(..),Eq(),Int)

{-
not doing the  HLIST style shape because I don't want to have
any pattern matchings going on.

Also would play hell with locality quality in the address translation hackery,
because there'd be an extra load to get those ints!
-}
infixr 3 :*
    
 {-
the concern basically boils down to "will it specialize / inline well"

 -}
data Shape (rank :: Nat) a where 
    Nil  :: Shape Z a
    (:*) ::  !(a) -> !(Shape r a ) -> Shape  (S r) a
    
--deriving instance (Show (Shape rank a))

    -- deriving instance Eq (Shape rank a)


    -- #if defined( __GLASGOW_HASKELL__ ) &&  ( __GLASGOW_HASKELL__  >= 707)
    --deriving instance Typeable (Shape rank a)
    -- #endif    



instance Functor (Shape Z) where

    fmap  = \ f Nil -> Nil 
    {-# INLINABLE fmap #-}
    
{-# SPECIALIZE fmap :: (Int ->Int )-> (Shape Z Int)-> (Shape Z Int) #-}

instance  (Functor (Shape r)) => Functor (Shape (S r)) where

    fmap  = \ f (a :* rest) -> f a :* fmap f rest 
    {-# INLINABLE fmap  #-}

{-# SPECIALIZE fmap :: (Int ->Int )-> (Shape (S Z) Int)-> (Shape (S Z) Int) #-}
{-# SPECIALIZE fmap :: (Int ->Int )-> (Shape (S (S Z)) Int)-> (Shape (S (S Z)) Int) #-}

instance  Applicative (Shape Z) where 
    pure = \ a -> Nil
    {-# INLINABLE pure #-}

    (<*>) = \ a  b -> Nil 
    {-# INLINABLE (<*>) #-}

{-# SPECIALIZE pure  :: Int -> Shape Z Int #-}
{-# SPECIALIZE (<*>) ::  Shape Z (Int -> Int) -> Shape Z Int -> Shape Z Int #-}

instance  Applicative (Shape a)=> Applicative (Shape (S a)) where     
    pure = \ a -> a :* (pure a)
    {-# INLINABLE pure  #-}

    (<*>) = \ (f:* fs) (a :* as) ->  f a :* (<*>) fs as 
    {-# INLINABLE (<*>) #-}

{-# SPECIALIZE pure :: Int -> Shape Z Int #-}    
{-# #-}

instance Foldable (Shape Z) where
    foldMap = \ f _ -> mempty
    {-# INLINABLE #-}

    foldl = \ f init  _ -> init 
    {-# INLINABLE foldl #-}

    foldr = \ f init _ -> init 
    {-# INLINABLE foldr #-}

    foldr' = \f !init _ -> init 
    {-# INLINABLE foldr' #-}

    foldl' = \f !init _ -> init   
    {-# INLINABLE foldl' #-}

instance (Foldable (Shape r))  => Foldable (Shape (S r)) where
    foldMap = \f  (a:* as) -> f a <> foldMap f as 
    {-# INLINABLE foldmap #-}

    foldl' = \f !init (a :* as) -> let   next = f  init a   in     next `seq` foldl f next as 
    {-# INLINABLE foldl' #-}

    foldr' = \f !init (a :* as ) -> f a $! foldr f init as               
    {-# INLINABLE foldr' #-}

    foldl = \f init (a :* as) -> let   next = f  init a  in   foldl f next as 
    {-# INLINABLE foldl #-}

    foldr = \f init (a :* as ) -> f a $ foldr f init as     
    {-# INLINABLE foldr  #-}

--
map2 :: (Applicative (Shape r))=> (a->b ->c) -> (Shape r a) -> (Shape r b) -> (Shape r c )
map2 = \f l r -> pure f <*>  l  <*> r 


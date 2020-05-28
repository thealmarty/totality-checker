module SPos where

import           Control.Monad.State
import           Evaluator
import           Types

-- to check data type declarations, one has to check that
-- constructors are strictly positive, which requires:
-- (1) the non-occurrence of an atomic value (nonOccur)
-- (2) the strict positive occurrence of an atomic value (spos)
-- spos embodies nonOccur.
--
-- check that recursive data argument n and
-- the spos declared parameter variables are only used strictly positively
sposConstructor :: Name -> Int -> [Pos] -> Value -> TypeCheck ()
sposConstructor n k sp (VPi x av env b) = do
  spr <- spos 0 (VDef n) av
  spv <- sposVals (posGen 0 sp) av
  case (spr, spv) of
    (True, True) -> do
      bv <- eval (updateEnv env x (VGen k)) b
      sposConstructor n (k + 1) sp bv
    (False, _) -> error "rec. arg not strictly positive"
    (True, False) -> error "parameter not strictly positive"
sposConstructor _n _k _sp _ = return ()

sposVals :: [Value] -> Value -> TypeCheck Bool
sposVals vals tv = do
  sl <- mapM (\i -> spos 0 i tv) vals
  return $ and sl

posGen :: Int -> [Pos] -> [Value]
posGen _i [] = []
posGen i (p:pl) =
  case p of
    SPos  -> VGen i : posGen (i + 1) pl
    NSPos -> posGen (i + 1) pl

posArgs :: [Value] -> [Pos] -> ([Value], [Value])
posArgs vl pl =
  let l = zip vl pl
      l1 = [v | (v, SPos) <- l]
      l2 = [v | (v, NSPos) <- l]
   in (l1, l2)

-- check that a does occurs strictly pos tv
-- a is an atomic value.
spos :: Int -> Value -> Value -> TypeCheck Bool
spos k a (VPi x av env b) = do
  no <- nonOccur k a av
  if no
    then do
      bv <- eval (updateEnv env x (VGen k)) b
      spos (k + 1) a bv
    else return False
spos k a (VLam x env b) = do
  bv <- eval (updateEnv env x (VGen k)) b
  spos (k + 1) a bv
spos k a (VSucc v) = spos k a v
spos k a (VApp (VDef m) vl) = do
  sig <- get
  case lookupSig m sig of
    (DataSig p pos _ _) -> do
      let (pparams, nparams) = posArgs vl pos
      let rest = drop p vl
      sl <- mapM (spos k a) pparams
      nl <- mapM (nonOccur k a) (nparams <> rest)
      return $ and sl && and nl
    _ -> do
      nl <- mapM (nonOccur k a) vl
      return $ and nl
spos k a (VApp v' vl) =
  if v' == a
    then do
      nl <- mapM (nonOccur k a) vl
      return $ and nl
    else do
      n <- nonOccur k a v'
      nl <- mapM (nonOccur k a) vl
      return $ n && and nl
spos _k _a _ = return True

-- non-occurrence check of atomic value a:
-- check that a (2nd input) does not occur in tv (3rd input)
-- a is an atomic value i.e not pi, lam, app, or succ
nonOccur :: Int -> Value -> Value -> TypeCheck Bool
nonOccur k a (VPi x av env b) = do
  aNotInav <- nonOccur k a av
  if aNotInav
    then do
      bv <- eval (updateEnv env x (VGen k)) b -- put x in env and eval
      nonOccur (k + 1) a bv -- check the next k
    else return False
nonOccur k a (VLam x env b) = do
  bv <- eval (updateEnv env x (VGen k)) b
  nonOccur (k + 1) a bv
nonOccur k a (VApp x vs) = do
  aNotInx <- nonOccur k a x
  listNotInvs <- mapM (nonOccur k a) vs
  return $ aNotInx && and listNotInvs
nonOccur k a (VSucc v) = nonOccur k a v
-- given tv is an atomic value, if a ≠ tv, then a doesn't occur in tv
nonOccur _k a tv = return $ a /= tv

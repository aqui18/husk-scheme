{-
 - skim-scheme
 - Types
 -
 - This file contains top-level data type definitions and their associated functions, including:
 -  - Scheme data types
 -  - Scheme errors
 -
 - @author Justin Ethier
 -
 - -}
module Skim.Types where
import Control.Monad
import Control.Monad.Error
import Char
import Data.Array
import Data.IORef
import Maybe
import List
import IO hiding (try)
import Numeric
import System.Environment
import Text.ParserCombinators.Parsec hiding (spaces)

{-  Environment management -}
type Env = IORef [((String, String), IORef LispVal)] -- lookup via: (namespace, variable)

nullEnv :: IO Env
nullEnv = newIORef []

macroNamespace = "m"
varNamespace = "v"

{- Scheme error handling -}
data LispError = NumArgs Integer [LispVal]
  | TypeMismatch String LispVal
  | Parser ParseError
  | BadSpecialForm String LispVal
  | NotFunction String String
  | UnboundVar String String
  | Default String

showError :: LispError -> String
showError (NumArgs expected found) = "Expected " ++ show expected
                                  ++ " args; found values " ++ unwordsList found
showError (TypeMismatch expected found) = "Invalid type: expected " ++ expected
                                  ++ ", found " ++ show found
showError (Parser parseErr) = "Parse error at " ++ ": " ++ show parseErr
showError (BadSpecialForm message form) = message ++ ": " ++ show form
showError (NotFunction message func) = message ++ ": " ++ show func
showError (UnboundVar message varname) = message ++ ": " ++ varname

instance Show LispError where show = showError
instance Error LispError where
  noMsg = Default "An error has occurred"
  strMsg = Default

type ThrowsError = Either LispError

trapError action = catchError action (return . show)

extractValue :: ThrowsError a -> a
extractValue (Right val) = val

type IOThrowsError = ErrorT LispError IO

liftThrows :: ThrowsError a -> IOThrowsError a
liftThrows (Left err) = throwError err
liftThrows (Right val) = return val

runIOThrows :: IOThrowsError String -> IO String
runIOThrows action = runErrorT (trapError action) >>= return . extractValue


{-  Scheme data types  -}
data LispVal = Atom String
	| List [LispVal]
	| DottedList [LispVal] LispVal
	| Vector (Array Int LispVal)
	| Number Integer
	| Float Float
 	| String String
	| Char Char
	| Bool Bool
	| PrimitiveFunc ([LispVal] -> ThrowsError LispVal)
	| Func {params :: [String], vararg :: (Maybe String),
	        body :: [LispVal], closure :: Env}
	| IOFunc ([LispVal] -> IOThrowsError LispVal)
	| Port Handle
    | Nil String -- String is probably wrong type here, but OK for now (do not expect to use this much, just internally)

showVal :: LispVal -> String
showVal (Nil _) = ""
showVal (String contents) = "\"" ++ contents ++ "\""
showVal (Char chr) = [chr]
showVal (Atom name) = name
showVal (Number contents) = show contents
showVal (Float contents) = show contents
showVal (Bool True) = "#t"
showVal (Bool False) = "#f"
showVal (Vector contents) = "#(" ++ (unwordsList $ Data.Array.elems contents) ++ ")"
showVal (List contents) = "(" ++ unwordsList contents ++ ")"
showVal (DottedList head tail) = "(" ++ unwordsList head ++ " . " ++ showVal tail ++ ")"
showVal (PrimitiveFunc _) = "<primitive>"
showVal (Func {params = args, vararg = varargs, body = body, closure = env}) = 
  "(lambda (" ++ unwords (map show args) ++
    (case varargs of
      Nothing -> ""
      Just arg -> " . " ++ arg) ++ ") ...)"
showVal (Port _) = "<IO port>"
showVal (IOFunc _) = "<IO primitive>"

unwordsList :: [LispVal] -> String
unwordsList = unwords . map showVal

{- Allow conversion of lispval instances to strings -}
instance Show LispVal where show = showVal

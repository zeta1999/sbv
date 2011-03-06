-----------------------------------------------------------------------------
-- |
-- Module      :  Data.SBV.C.C
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
-- Portability :  portable
--
-- Compilation of symbolic programs to C
-----------------------------------------------------------------------------

module Data.SBV.C.C(compileToC) where

import Data.SBV.BitVectors.Data (runSymbolic, Result, Symbolic)

-- | Given a symbolic computation, render it as an equivalent
--   C program. The first argument is an optional directory name
--   under which the files will be saved. If `Nothing`, the result
--   will be written to stdout. Use @`Just` \".\"@ for creating files in
--   the current directory. The second argument is name of the function,
--   which also forms the names of the C and header files.
compileToC :: Maybe FilePath -> String -> Symbolic a -> IO ()
compileToC mbDirName nm c = do
   putStrLn "Performing symbolic execution.."
   res <- runSymbolic c
   cp <- symbolicToC nm res
   putStrLn "Rendering as a C program.."
   renderC mbDirName cp
   putStrLn "Done."

data CPgm = CPgm { makeFile :: [String]
                 , cHeader  :: [String]
                 , cProg    :: [String]
                 }

symbolicToC :: String -> Result -> IO CPgm
symbolicToC nm c = return $ CPgm [] [] []

renderC :: Maybe FilePath -> CPgm -> IO ()
renderC mbDirName cp = return ()

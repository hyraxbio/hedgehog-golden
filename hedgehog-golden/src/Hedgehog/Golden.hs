module Hedgehog.Golden
  ( goldenTests
  , GoldenTest
  ) where

import Prelude

import           Control.Monad (when)
import           Data.Traversable (traverse)
import           Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import           GHC.Stack (CallStack, getCallStack)
import qualified Hedgehog.Internal.Seed as Seed
import           Hedgehog.Golden.Internal.Source as Source
import           System.Exit (exitFailure)
import           Hedgehog.Golden.Types (GoldenTest(..), ValueGenerator)

data TestResult
  = NewFileFailure
  | Success
  deriving Eq

goldenTests :: [IO GoldenTest] -> IO ()
goldenTests tests = do
  sequence tests >>= traverse applyTest >>= checkErrors

checkErrors :: [TestResult] -> IO ()
checkErrors results =
  when (any (/= Success) results) exitFailure

applyTest :: GoldenTest -> IO TestResult
applyTest = \case
  NewFile cs fp gen -> newGoldenFile cs fp gen
  ExistingFile _ fp gen -> existingGoldenFile fp gen

newGoldenFile :: CallStack -> FilePath -> ValueGenerator -> IO TestResult
newGoldenFile cs (Text.pack -> fp) gen =
  let
    outputLines = Text.putStrLn . Text.intercalate "\n"
    srcLoc = snd . head . getCallStack $ cs
    renderAddedFile seed =
      [ "", Source.yellow "Generated golden will be saved in: " <> fp] ++
      [ Source.boxTop ] ++
      Source.addLineNumbers (Source.added <$> gen seed) ++
      [ Source.boxBottom ]
  in do
    seed <- Seed.random
    callsite <- Source.renderCallsite srcLoc

    -- Render interface:
    outputLines $ callsite ++ renderAddedFile seed

    -- Run interactive mode if run via repl:
    if Source.isInteractive srcLoc then do
      outputLines . renderAcceptNew $ fp
      pure Success
    else do
      outputLines newFileError
      pure NewFileFailure

newFileError :: [Text]
newFileError =
  [ Source.red "✗ New file" <> " re-run tests interactively to add missing file"
  , ""
  ]

renderAcceptNew :: Text -> [Text]
renderAcceptNew filePath =
  [ ""
  , "  Accept new golden file?"
  , ""
  , Source.green  "    A" <> Source.white ")ccept" <> "     save new file"
  , Source.red    "    r" <> Source.white ")eject" <> "     keep old golden file"
  , Source.yellow "    s" <> Source.white ")kip" <> "       saves generated source to: " <> filePath <> ".new"
  , ""
  ]

existingGoldenFile :: FilePath -> ValueGenerator -> IO TestResult
existingGoldenFile _ _ = undefined

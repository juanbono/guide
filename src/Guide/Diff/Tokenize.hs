{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}


-- | Prepare text for diffing or merging by breaking it into tokens (like
-- links or Markdown elements).
module Guide.Diff.Tokenize
(
  tokenize,
)
where


import Imports

-- Text
import qualified Data.Text.All as T
import Data.List.Split


-- | Break text into tokens.
tokenize :: Text -> [Text]
tokenize = consolidate . map T.toStrict . break' . T.toString

-- | Break a string into words, spaces, and special characters.
break' :: String -> [String]
break' = split . dropInitBlank . dropFinalBlank . dropInnerBlanks . whenElt $
  \c -> not (isAlphaNum c) && c /= '\''

-- | Consolidate some of the things into tokens.
consolidate :: [Text] -> [Text]
-- a word followed by a space, dot, or comma (this is needed to prevent
-- spaces from being detected as “unchanged parts” and also to make diffs
-- faster)
consolidate (w:c:r)
  | T.all (\t -> isLetter t || t == '\'') w && c `elem` [" ",".",","] =
      (w <> c) : consolidate r
-- glue newlines to ends of their lines
consolidate (w:"\n":r)
  | not ("\n" `T.isSuffixOf` w) =
      (w <> "\n") : consolidate r
-- spaces
consolidate s@(" ":_) =
  let (l, r) = span (== " ") s
  in T.concat l : consolidate r
-- breaks between paragraphs
consolidate s@("\n":_) =
  let (l, r) = span (== "\n") s
  in T.concat l : consolidate r
-- code block markers
consolidate s@("~":_) =
  let (l, r) = span (== "~") s
  in if length l >= 3 then T.concat l : consolidate r else l ++ consolidate r
consolidate s@("`":_) =
  let (l, r) = span (== "`") s
  in if length l >= 3 then T.concat l : consolidate r else l ++ consolidate r
-- hrules
consolidate s@("-":_) =
  let (l, r) = span (== "-") s
  in if length l >= 3 then T.concat l : consolidate r else l ++ consolidate r
-- ellipses
consolidate (".":".":".":xs) = "..." : consolidate xs
-- links
consolidate s@("http":":":"/":"/":_) =
  let (l, r) = span (\x -> x /= ")" && not (isSpace (T.head x))) s
  in  T.concat l : consolidate r
consolidate s@("https":":":"/":"/":_) =
  let (l, r) = span (\x -> x /= ")" && not (isSpace (T.head x))) s
  in  T.concat l : consolidate r
consolidate ("(":"@":"hk":")":xs) = "(" : "@hk" : ")" : consolidate xs

-- Haskell operators
consolidate (op -> (x, xs))
  | not (T.null x) = x : consolidate xs
-- Haskell tokens
consolidate ("[":"]":xs) = "[]" : consolidate xs
consolidate ("(":")":xs) = "()" : consolidate xs
consolidate ("[":"|":xs) = "[|" : consolidate xs
consolidate ("|":"]":xs) = "|]" : consolidate xs

-- the rest
consolidate (x:xs) = x : consolidate xs
consolidate [] = []

-- | Helpful view pattern for matching operators
op :: [Text] -> (Text, [Text])
op = over _1 mconcat . span (isOpToken . T.unpack)
  where
    isOpToken [c] = c `elem` (":!#$%&*+./<=>?@\\^|-~" :: String)
    isOpToken _   = False

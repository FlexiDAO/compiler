{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
module Reporting.Render.Type.Localizer
  ( Localizer
  , toDoc
  , empty
  , fromNames
  , fromModule
  , replEmpty
  , replAdd
  )
  where


import qualified Data.Map as Map
import qualified Data.Set as Set

import qualified AST.Source as Src
import qualified AST.Valid as Valid
import qualified Elm.Compiler.Imports as Imports
import qualified Elm.Name as N
import qualified Elm.Package as Pkg
import Reporting.Doc ((<>))
import qualified Reporting.Doc as D
import qualified Reporting.Annotation as A



-- LOCALIZER


newtype Localizer =
  Localizer (Map.Map N.Name Import)


data Import =
  Import
    { _alias :: Maybe N.Name
    , _exposing :: Exposing
    }


data Exposing
  = All
  | Only (Set.Set N.Name)


empty :: Localizer
empty =
  Localizer Map.empty



-- LOCALIZE


toDoc :: Localizer -> N.Name -> N.Name -> D.Doc
toDoc (Localizer localizer) home name =
  case Map.lookup home localizer of
    Nothing ->
      D.fromName home <> "." <> D.fromName name

    Just (Import alias exposing) ->
      case exposing of
        All ->
          D.fromName name

        Only set ->
          if Set.member name set then
            D.fromName name
          else
            D.fromName (maybe home id alias) <> "." <> D.fromName name



-- FROM NAMES


fromNames :: Map.Map N.Name a -> Localizer
fromNames names =
  Localizer $ Map.map (\_ -> Import Nothing All) names



-- FROM MODULE


fromModule :: Valid.Module -> Localizer
fromModule (Valid.Module name _ _ _ imports _ _ _ _ _) =
  Localizer $ Map.fromList $
    (name, Import Nothing All) : map toPair imports


toPair :: Src.Import -> (N.Name, Import)
toPair (Src.Import (A.At _ name) alias exposing) =
  ( name
  , Import alias (toExposing exposing)
  )


toExposing :: Src.Exposing -> Exposing
toExposing exposing =
  case exposing of
    Src.Open ->
      All

    Src.Explicit exposedList ->
      Only (foldr addType Set.empty exposedList)


addType :: A.Located Src.Exposed -> Set.Set N.Name -> Set.Set N.Name
addType (A.At _ exposed) types =
  case exposed of
    Src.Lower _      -> types
    Src.Upper name _ -> Set.insert name types
    Src.Operator _   -> types



-- REPL STUFF


replEmpty :: Localizer
replEmpty =
  Localizer $ Map.fromList $ map toPair $
    Imports.addDefaults Pkg.dummyName []


replAdd :: N.Name -> Maybe N.Name -> Src.Exposing -> Localizer -> Localizer
replAdd name alias exposing (Localizer localizer) =
  Localizer $ Map.insert name (Import alias (toExposing exposing)) localizer


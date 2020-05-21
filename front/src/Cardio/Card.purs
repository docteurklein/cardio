module Cardio.Card where

import Prelude

import Data.Either (hush, Either(..))
import Data.Tuple.Nested ((/\))
import Data.Maybe (Maybe(..))
import Effect.Aff (attempt)
import Effect.Aff.Class (class MonadAff)
import Effect.Console (log, logShow)
import Halogen (Component, ComponentHTML, mkComponent, mkEval, defaultEval, HalogenM, modify_, liftEffect, gets, liftAff)
import Halogen.Hooks as Hooks
import Halogen.HTML
import Halogen.HTML.Events (onSubmit, onValueInput)
import Halogen.HTML.Properties
import Milkis (text, fetch, Fetch, URL(..), defaultFetchOptions) as M
import Milkis.Impl.Window (windowFetch)
import Network.RemoteData (RemoteData(..), _Success, fromMaybe, toMaybe)
import Web.Event.Event (Event)
import Web.Event.Event as Event

component :: forall f i o m. MonadAff m => Component HTML f i o m
component = Hooks.component \_ _ -> Hooks.do
  state /\ stateId <- Hooks.useState $ { title: "", result: NotAsked }

  let
    handleTitle = Hooks.put stateId \a -> (_ { title = a })
    handleSubmit = Hooks.modify_ stateId show

  Hooks.pure do
      form
        [ onSubmit (Just <<< handleSubmit) ]
        [ h1_ [ text "Create card" ]
        , label_
            [ div_ [ text "Enter title:" ]
            , input
                [ value state.title
                , onValueInput (Just <<< handleTitle)
                ]
            ]
        , button
            [ type_ ButtonSubmit ]
            [ text "Create" ]
        , div_
            case state.result of
              NotAsked -> []
              Loading -> [text "loading…"]
              Failure e -> [text "failed!", text e]
              Success res ->
                [ h2_
                    [ text "Response:" ]
                , pre_
                    [ code_ [ text res ] ]
                ]
        ]

-- handleAction :: forall o m. MonadAff m => Action -> HalogenM State Action () o m Unit
-- handleAction = case _ of
--   SetTitle title -> do
--     modify_ (_ { title = title })
--   MakeRequest event -> do
--     liftEffect $ Event.preventDefault event
--     title <- gets _.title
--     modify_ (_ { result = Loading })
--     response <- liftAff $ attempt $ M.text =<< fetch (M.URL ("http://api.github.com/users/" <> title)) M.defaultFetchOptions
--     case response of
--         Left e -> modify_ (_ { result = Failure $ show e  })
--         Right body -> do
--             modify_ (_ { result = Success $ body  })

fetch :: M.Fetch
fetch = M.fetch windowFetch

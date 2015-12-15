{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module EventRulesSpec (spec) where

import           Control.Arrow
import           Control.Lens
import qualified Data.Map                  as Map
import           Data.UUID
import           EventRules
import           Test.Hspec
import           Test.QuickCheck
import           Test.QuickCheck.Instances ()
import           Types                     (Position (..))
import           Utils

instance Arbitrary UUID where
  arbitrary = fromWords <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary PlayerEvent where
  arbitrary = oneof [pure Join,pure Leave,SetName <$> arbitrary]

instance Arbitrary Event where
  arbitrary = FromPlayer <$> arbitrary <*> arbitrary

spec :: Spec
spec = do playerEventSpec

eventsCause :: [(Event,Time)] -> Time -> (Scene,[Reaction]) -> Expectation
eventsCause events time expected = sceneAt time schedule `shouldBe` expected
  where schedule = scheduleFrom Map.empty events

playerEventSpec :: Spec
playerEventSpec =
  describe "Player Events" $
  do it "Join and name should result in one named player" . property $
       \(t,uuid,name) ->
         eventsCause
           [(FromPlayer uuid Join,t)
           ,(FromPlayer uuid
                        (SetName name)
            ,addTime 5 t)]
           (addTime 10 t)
           (Scene {_players =
                     Map.fromList
                       [(uuid
                        ,set playerName name (initialPlayer (Position 1 1)))]}
           ,[])
     it "Removing a non-existent player shouldn't matter." . property $
       \(t,uuid) ->
         eventsCause [(FromPlayer uuid Leave,t)]
                     (addTime 10 t)
                     (Scene Map.empty,[])
     it "Adding n players results in n players." . property $
       \((NonEmpty srcs) :: NonEmptyList (UUID,Time)) ->
         let events = fmap (first (\uuid -> FromPlayer uuid Join)) srcs
             lastTime = maximum (snd <$> srcs)
             (scene,_) = sceneAt lastTime (scheduleFrom Map.empty events)
         in length (_players scene) == length srcs
     it "Double adding a player causes an error." . property $
       \(t1,t2,uuid) ->
         eventsCause
           [(FromPlayer uuid Join,t1),(FromPlayer uuid Join,t2)]
           (max t1 t2)
           (Scene {_players =
                     Map.fromList [(uuid,initialPlayer (Position 1 1))]}
           ,[PlayerAlreadyAdded uuid])
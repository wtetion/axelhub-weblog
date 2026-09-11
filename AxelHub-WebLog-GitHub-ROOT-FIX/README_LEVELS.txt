Player Log now shows Base Level and Treadmill Level.

The Luau reader now checks:
- named save fields (BaseLevel/BaseTier, TreadmillLevel/TreadmillTier, etc.)
- nested tables under Base/Homestead/Plot or Treadmill/Training/Speed containers
- live plot attributes and NumberValue/IntValue instances
- GUI labels containing Level/Tier

It also avoids treating an unrelated generic Level in the whole save as the Base Level.

Auto Treadmill return now finds TreadmillBottom recursively and uses the actual treadmill height instead of a fixed Y, then verifies arrival before mounting.

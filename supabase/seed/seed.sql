-- Seed Would You Rather challenges for development/testing
insert into public.challenges (option_a, option_b, category, difficulty) values
  -- Lifestyle (8)
  ('Always be 10 minutes late', 'Always be 20 minutes early', 'lifestyle', 1),
  ('Live in a treehouse', 'Live in a houseboat', 'lifestyle', 1),
  ('Have a personal chef', 'Have a personal trainer', 'lifestyle', 2),
  ('Live without internet', 'Live without AC/heating', 'lifestyle', 3),
  ('Give up your phone', 'Give up your bed', 'lifestyle', 3),
  ('Wear the same outfit every day', 'Never eat the same meal twice', 'lifestyle', 2),
  ('Live in a tiny house', 'Live in a mansion you can never leave', 'lifestyle', 4),
  ('Wake up at 4 AM every day', 'Stay up until 4 AM every night', 'lifestyle', 2),

  -- Food (7)
  ('Only eat pizza forever', 'Only eat tacos forever', 'food', 1),
  ('Never eat sweets again', 'Never eat savory food again', 'food', 3),
  ('Eat only raw food', 'Eat only canned food', 'food', 2),
  ('Drink only water forever', 'Drink everything except water', 'food', 3),
  ('Always cook your own meals', 'Always eat out but at random restaurants', 'food', 2),
  ('Have taste buds on your fingers', 'Have fingers for taste buds', 'food', 5),
  ('Only eat breakfast food', 'Never eat breakfast food again', 'food', 1),

  -- Travel (7)
  ('Explore deep space', 'Explore the deep ocean', 'travel', 2),
  ('Travel the world for a year with no luggage', 'Stay home for a year with unlimited online shopping', 'travel', 2),
  ('Only travel by bicycle', 'Only travel by boat', 'travel', 3),
  ('Visit every country but only for one hour', 'Live in one country forever', 'travel', 3),
  ('Always sit in the middle seat', 'Always have a 12-hour layover', 'travel', 2),
  ('Teleport anywhere but arrive naked', 'Fly but only at walking speed', 'travel', 4),
  ('Live on a tropical island alone', 'Live in a big city with a million roommates', 'travel', 3),

  -- Entertainment (7)
  ('Never use social media again', 'Never watch TV/movies again', 'entertainment', 2),
  ('Only listen to one song forever', 'Never listen to music again', 'entertainment', 4),
  ('Be in a reality TV show', 'Be the host of a game show', 'entertainment', 2),
  ('Only watch movies made before 1970', 'Only watch movies that haven''t been released yet', 'entertainment', 3),
  ('Play one video game for the rest of your life', 'Never play video games again', 'entertainment', 3),
  ('Read minds but only boring thoughts', 'See the future but only 10 seconds ahead', 'entertainment', 4),
  ('Have your life narrated by Morgan Freeman', 'Have your life scored by Hans Zimmer', 'entertainment', 1),

  -- Relationships (7)
  ('Always speak your mind', 'Never speak again', 'relationships', 4),
  ('Be the funniest person in the room', 'Be the smartest person in the room', 'relationships', 3),
  ('Always know when someone is lying', 'Always get away with lying', 'relationships', 4),
  ('Have one best friend who knows everything about you', 'Have 100 friends who know nothing about you', 'relationships', 3),
  ('Always have to say yes', 'Always have to say no', 'relationships', 3),
  ('Know how every relationship ends', 'Never know how anyone feels about you', 'relationships', 5),
  ('Be loved by everyone but trust no one', 'Be trusted by everyone but loved by no one', 'relationships', 5),

  -- Career (7)
  ('Be famous but hated', 'Be unknown but loved', 'career', 3),
  ('Work your dream job for minimum wage', 'Work a boring job for a million dollars a year', 'career', 3),
  ('Be your own boss but work 80 hours a week', 'Work 20 hours a week but have a terrible boss', 'career', 3),
  ('Be an astronaut', 'Be a deep sea diver', 'career', 1),
  ('Have a job where you travel 100% of the time', 'Have a job where you work from home 100% of the time', 'career', 2),
  ('Be the world''s best at something nobody cares about', 'Be average at something everyone admires', 'career', 4),
  ('Retire at 30 with $1M', 'Retire at 60 with $10M', 'career', 4),

  -- Hypothetical (8)
  ('Travel to the past', 'Travel to the future', 'hypothetical', 2),
  ('Have unlimited money', 'Have unlimited time', 'hypothetical', 3),
  ('Have a rewind button for life', 'Have a pause button for life', 'hypothetical', 3),
  ('Be able to fly', 'Be able to read minds', 'hypothetical', 2),
  ('Win the lottery', 'Live twice as long', 'hypothetical', 4),
  ('Never age physically', 'Never age mentally', 'hypothetical', 5),
  ('Know the date of your death', 'Know the cause of your death', 'hypothetical', 5),
  ('Have all traffic lights be green for you', 'Never have to wait in line again', 'hypothetical', 1),

  -- Silly (9)
  ('Always feel too hot', 'Always feel too cold', 'silly', 1),
  ('Have fingers as long as your legs', 'Have legs as long as your fingers', 'silly', 2),
  ('Sweat maple syrup', 'Cry lemonade', 'silly', 2),
  ('Have a permanent clown nose', 'Have permanent clown shoes', 'silly', 1),
  ('Speak every language but only in whispers', 'Speak one language but always shouting', 'silly', 3),
  ('Have spaghetti for hair', 'Have marshmallows for teeth', 'silly', 2),
  ('Hiccup every time you say your name', 'Sneeze every time someone says thank you', 'silly', 1),
  ('Sound like a duck when you laugh', 'Sound like a goat when you sing', 'silly', 1),
  ('Have T-Rex arms', 'Have giraffe legs', 'silly', 2);

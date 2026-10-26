# Task 4.1: Write up

## Who acts on the per-producer breakdown

I'd give it to the regional operations manager in each city the person who manages the listing agents. They're the one who can actually change how viewings get run at a property, for example getting the agent to confirm each viewing the day before. So the Danang manager would look at property 2 first (3 no-shows out of 16, 18.8%) and the Haiphong manager would look at property 3 (2 out of 13, 15.4%).

I wouldn't send it to whoever signs off on agent commissions. 13 or 16 viewings is too few to base anyones pay on and the Unit 3 payout freeze happened bc someone acted on a bad number.

## What the aggregates hide

The avg viewing length for the platform is 18.14 minutes but that includes 34 cancelled viewings that were saved as 0 minutes so its pulled down by viewings that never happened. The ones that did happen go from 4.65 to 70.86 minutes and avg 21.86. Property 11 has the lowest raw avg at 11.94 and you'd think renters leave there fast but 5 of its 16 viewings were canceled zeros. Without them its 17.37 which is about normal.

The no-show rate is 6% for the platform but for properties with 10 or more viewings it goes from 0% (four of them) to 18.8% (property 2). In the region by quarter table Danang has two quarters at 50% which are 2 of 4 and 1 of 2.

A properties no-show count is really counting renters who didn't show up. it isn't something the property did. It also doesn't say if property 2s 3 no-shows were 3 different people or one person 3 times and those would need different fixes.

The viewing count per property also includes cancelations that weren't the renters fault like the agent being unavailable or the property getting withdrawn. Those are on the agent or the landlord and they aren't in the 6% at all.

## What I'd need to see next

- More viewings per property bc 16 isn't enough to say property 2 is actually worse. If every property really had a 6% rate one with 16 viewings would still hit 3 or more no-shows about 7% of the time and with 12 properties theres roughly a 1 in 3 chance one of them looks this bad by luck. Another year of viewings would show if it stays high.
- No-shows broken down by renter. If a handful of renters cause most of them then the fix is on the renter side, like a deposit for people who keep not showing up.
- Which agent ran each viewing. The frozen payout was agent commissions but theres no agent column in viewings so theres no way to link a no-show or an agent unavailable cancellation to a person. That would be needed before any of this touches pay.
- When each viewing was booked and not just when it was scheduled. If the no-shows are mostly ones booked weeks out then reminders would probably help more than anything done at the property.

# Task 4.2: Write up

## Part A

The two questions are how many viewings did each property get and how many of those were renter no-shows. 4.2a puts both in the same row so each properties no-shows are next to its own volume.

2 and 3 are the outliers. Property 2 had 3 no-shows out of 16 (18.8%) and property 3 had 2 out of 13 (15.4%). They're the only two with more than one no-show and between them thats 5 of the 12 on the platform. Property 4 is at 16.7% too but thats 1 no-show out of 6 viewings under the 10 viewing cutoff from 4.1c, so I left it out.

## Part B

The regional director. They cover all five cities so a row for every property is too much for them, they just need one line per city to compare and the platform total to compare against.

The grand total is what you'd use to decide if no-shows are a platform-wide problem, the kind that would need something applied to everyone like deposits for every renter or freezing payouts again. Its 6.0% (12 of 200), same as Unit 3 found, so no. You can't get that from the city rows. They show Danang at 18.8% (which is only property 2) and Haiphong at 8.0%, so they're more for deciding where to follow up locally.

## Part C

The question is what no-show rate is normal for a busy property. The 8 properties with 15 or more viewings had 7 no-shows in 145 viewings so the baseline is 4.8% and their held viewings avg 22.31 minutes. Property 2 is at 18.8% so its almost 4 times that.

# Task 4.3: Reflection

With conditional aggregation the database reads the viewings table once. For each row it adds 1 to that propertys viewing count and if the reason is a renter no-show it also adds 1 to the no-show count. The other way is two separate queries. One counts all the viewings per property and the other has WHERE no_show_reason = 'Renter no show' so it only counts no-shows. Then you have to join them back together on property_id.

With 200 rows you would never notice a difference. With a million rows the two query way reads the whole table twice and if the table doesn't fit in memory thats double the disk reads. Then the join on top of that. The two queries also run at slightly different times. If new viewings get inserted in between them the total and the no-show count aren't from the same data so the rate is a little off. The filtered query also only returns properties that had a no-show. 5, 8, 10 and 13 had zero so they wouldn't be in it and an inner join would just drop them with no error, basically the Unit 3 problem again. You'd need a LEFT JOIN and COALESCE to get them back as 0. One pass gets both counts from the same rows so none of that comes up.

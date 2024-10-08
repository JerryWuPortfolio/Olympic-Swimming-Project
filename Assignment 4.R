library("tidyverse")
library("SwimmeR")
library("data.table")
library("pracma")
library("rstatix")
library("caret")
library("DescTools")
library("ggrepel")
library("equatiomatic")

#Question 1 Data Import & Boxplot Visualization

#Men's Result
filenames_men <- list.files("Tokyo 2020 swimming data/Men's individual/", pattern="*.pdf", full.names=TRUE)

datafiles_men <- list()

for (f_men in filenames_men){
  
  # Import 1 file at each iteration of the loop (f will take the value of each filename)
  data_men <- swim_parse(read_results(f_men))
  
  # Add the data from each iteration to the list
  datafiles_men[[f_men]] <- data_men
  
}

mens_individual_df <- rbindlist(datafiles_men)


#Women
filenames_women <- list.files("Tokyo 2020 swimming data/Women's individual/", pattern="*.pdf", full.names=TRUE)

datafiles_women <- list()

for (f_women in filenames_women){
  
  # Import 1 file at each iteration of the loop (f will take the value of each filename)
  data_women <- swim_parse(read_results(f_women))
  
  # Add the data from each iteration to the list
  datafiles_women[[f_women]] <- data_women
  
}

womens_individual_df <- rbindlist(datafiles_women)

#Data Cleaning
mens_individual_df <- mens_individual_df %>% 
  drop_na() %>%
  mutate(Finals = sec_format(Finals)) %>% #Change time format
  mutate(Lane = as.numeric(Lane)) %>% #Changing to numeric data type
  mutate(Reaction_Time = as.numeric(Reaction_Time))

womens_individual_df <- womens_individual_df %>% 
  drop_na() %>%
  mutate(Finals = sec_format(Finals)) %>%
  mutate(Lane = as.numeric(Lane)) %>%
  mutate(Reaction_Time = as.numeric(Reaction_Time))

#List of all Events
event_list_mens <- mens_individual_df %>%
  select(Event) %>%
  group_by(Event) %>%
  summarise()

#Determining and Removing Outlier for Mens
outlier_mens <- mens_individual_df %>% 
  group_by(Event) %>%
  identify_outliers(Finals)

mens_individual_df <- anti_join(mens_individual_df, outlier_mens, by = c("Name","Finals"))

#Determining and Removing Outlier for Womens
outlier_womens <- womens_individual_df %>% 
  group_by(Event) %>%
  identify_outliers(Finals)

womens_individual_df <- anti_join(womens_individual_df, outlier_womens, by = c("Name","Finals"))

#Visualisation
ggplot(mens_individual_df, mapping = aes(y = Finals, colour = Event)) + 
  geom_boxplot(outlier.shape = NA) + guides(x = guide_axis(angle = -30))  +
  labs(y = "Finals Time(Seconds)", title = "Final performance times for Mens Event") + 
  facet_wrap(~Event,scales = "free_y")

ggplot(womens_individual_df, mapping = aes(y = Finals, colour = Event)) + 
  geom_boxplot(outlier.shape = NA) + guides(x = guide_axis(angle = -30)) + 
  labs(y = "Finals Time(Seconds)", title = "Final performance times for Womens Event") + 
  facet_wrap(~Event,scales = "free_y")



#Question 2 Linear Regression Modelling

#Subsetting
womens_400m_freestyle_df <- womens_individual_df[Event == "Women's 400m Freestyle"]
mens_1500m_freestyle_df <- mens_individual_df[Event == "Men's 1500m Freestyle"]

#Linear Regression Model
set.seed(123) # For reproducibility
Index_women <- createDataPartition(womens_400m_freestyle_df$Finals, 
                                   p = 0.7,         # This says we want a 70-30 split
                                   list = FALSE, 
                                   times = 1)

train_women <- womens_400m_freestyle_df[Index_women, ]   # rows in the training indicies
test_women  <- womens_400m_freestyle_df[-Index_women, ]  # rows NOT in the training indicies

set.seed(123) # For reproducibility
Index_men <- createDataPartition(mens_1500m_freestyle_df$Finals, 
                                 p = 0.7,         # This says we want a 70-30 split
                                 list = FALSE, 
                                 times = 1)

train_men <- mens_1500m_freestyle_df[Index_men, ]   # rows in the training indicies
test_men  <- mens_1500m_freestyle_df[-Index_men, ]  # rows NOT in the training indicies

women_400_model <- lm(
  Finals ~ Reaction_Time,
  data = train_women
)

men_1500_model <- lm(
  Finals ~ Reaction_Time,
  data = train_men
)

summary(women_400_model)
summary(men_1500_model)

#Model Performance
pred_train_women <- predict(women_400_model, newdata = train_women)
pred_test_women <- predict(women_400_model, newdata = test_women)
mae_train_women <- mean(abs(pred_train_women - train_women$Finals))
mae_test_women <- mean(abs(pred_test_women - test_women$Finals))
rmse_train_women <- sqrt(mean((pred_train_women - train_women$Finals)^2))
rmse_test_women <- sqrt(mean((pred_test_women - test_women$Finals)^2))

pred_train_men <- predict(men_1500_model, newdata = train_men)
pred_test_men <- predict(men_1500_model, newdata = test_men)
mae_train_men <- mean(abs(pred_train_men - train_men$Finals))
mae_test_men <- mean(abs(pred_test_men - test_men$Finals))
rmse_train_men <- sqrt(mean((pred_train_men - train_men$Finals)^2))
rmse_test_men <- sqrt(mean((pred_test_men - test_men$Finals)^2))


#Question 3 Multiple Regression Modelling and Swim Event Time Prediction

#Gender variable
mens_individual_df <- mens_individual_df %>%
  mutate(Gender = c("Men"))

womens_individual_df <- womens_individual_df %>%
  mutate(Gender = c("Women"))

#Combine dataframe
full_individual_df <- rbind(mens_individual_df, womens_individual_df)

full_individual_df <- full_individual_df %>%
  mutate(Event_Distance = case_when(
    full_individual_df$Event %like% "%50m%" ~ 50,
    full_individual_df$Event %like% "%100%" ~ 100,
    full_individual_df$Event %like% "%200%" ~ 200,
    full_individual_df$Event %like% "%400%" ~ 400,
    full_individual_df$Event %like% "%800%" ~ 800,
    full_individual_df$Event %like% "%1500%" ~ 1500,
  ) 
  ) %>%
  mutate(Stroke_Type = case_when(
    full_individual_df$Event %like% "%Backstroke%" ~ "Backstroke",
    full_individual_df$Event %like% "%Breaststroke%" ~ "Breaststroke",
    full_individual_df$Event %like% "%Butterfly%" ~ "Butterfly",
    full_individual_df$Event %like% "%Freestyle%" ~ "Freestyle",
  )
  )

#Multiple Linear Regression Model
set.seed(123) # For reproducibility
Index_full <- createDataPartition(full_individual_df$Finals, 
                                  p = 0.7,         # This says we want a 70-30 split
                                  list = FALSE, 
                                  times = 1)

train_full <- full_individual_df[Index_full, ]   # rows in the training indicies
test_full <- full_individual_df[-Index_full, ]  # rows NOT in the training indicies

mvmod <- lm(
  Finals ~ Gender + Event_Distance + Stroke_Type,
  data = train_men
)

extract_eq(mvmod, use_coefs = T)

pred_train_full <- predict(nvmod, newdata = train_full)
pred_test_full <- predict(nvmod, newdata = test_full)
mae_train_full <- mean(abs(pred_train_full - train_full$Finals))
mae_test_full <- mean(abs(pred_test_full - test_full$Finals))
rmse_train_full <- sqrt(mean((pred_train_full - train_full$Finals)^2))
rmse_test_full <- sqrt(mean((pred_test_full - test_full$Finals)^2))

#Predicting Event Lap Times
predict(mvmod, newdata = data.frame(Gender = "Men", Event_Distance = 100, Stroke_Type = "Butterfly"))/2
predict(mvmod, newdata = data.frame(Gender = "Women", Event_Distance = 5000, Stroke_Type = "Freestyle"))/100



#Question 4 Data Visualization of Ariarne Titmus’ Performance in the 400m Freestyle Events

heat_400 <- swim_parse(read_results("Tokyo 2020 swimming data/Women's individual/SWMW400MFR_HEAT.pdf"), splits = TRUE) 

heat_400 <- heat_400 %>%
  mutate_at(c(11:18), as.numeric)


final_400 <- swim_parse(read_results("Tokyo 2020 swimming data/Women's individual/SWMW400MFR_FNL.pdf"), splits = TRUE)

final_400 <- final_400 %>%
  mutate_at(c(11:18), as.numeric)

Ariarne_Titmus <- rbind(filter(heat_400, Name == "TITMUS Ariarne"),
                        filter(final_400, Name == "TITMUS Ariarne")) %>%
  mutate_at(c(11:18), as.numeric) %>%
  mutate(time_50 = .[,11]) %>%
  mutate(time_100 = .[,11] + .[,12]) %>%
  mutate(time_150 = .[,20] + .[,13]) %>%
  mutate(time_200 = .[,21] + .[,14]) %>%
  mutate(time_250 = .[,22] + .[,15]) %>%
  mutate(time_300 = .[,23] + .[,16]) %>%
  mutate(time_350 = .[,24] + .[,17]) %>%
  mutate(time_400 = .[,25] + .[,18])


#Ariarne_Titmus[1,11] #50m split
cumulative_time_heat <- heat_400 %>%
  mutate(time_50 = .[,11]) %>%
  mutate(time_100 = .[,11] + .[,12]) %>%
  mutate(time_150 = .[,20] + .[,13]) %>%
  mutate(time_200 = .[,21] + .[,14]) %>%
  mutate(time_250 = .[,22] + .[,15]) %>%
  mutate(time_300 = .[,23] + .[,16]) %>%
  mutate(time_350 = .[,24] + .[,17]) %>%
  mutate(time_400 = .[,25] + .[,18]) %>%
  select(c(4,19:26))

cumulative_time_final <- final_400 %>%
  mutate(time_50 = .[,11]) %>%
  mutate(time_100 = .[,11] + .[,12]) %>%
  mutate(time_150 = .[,20] + .[,13]) %>%
  mutate(time_200 = .[,21] + .[,14]) %>%
  mutate(time_250 = .[,22] + .[,15]) %>%
  mutate(time_300 = .[,23] + .[,16]) %>%
  mutate(time_350 = .[,24] + .[,17]) %>%
  mutate(time_400 = .[,25] + .[,18]) %>%
  select(c(4,19:26))

#Calculate Time difference at each split
for(i in c(2:9)){
  cumulative_time_heat[,8+i] <- abs(cumulative_time_heat[,i] - cumulative_time_heat[19,i])
  cumulative_time_final[,8+i] <- abs(cumulative_time_final[,i] - cumulative_time_final[1,i])
}

#Difference in split time, taking out Ariarne Titmus
diff_heat <- cumulative_time_heat %>%
  select(c(1,10:17)) %>%
  filter(Name != "TITMUS Ariarne")

diff_final <- cumulative_time_final %>%
  select(c(1,10:17)) %>%
  filter(Name != "TITMUS Ariarne")

#Finding the index
heat_index <- list()
final_index <- list()

heat_index <- apply(diff_heat[,2:9], 2, which.min)
final_index <- apply(diff_final[,2:9], 2, which.min)

#Adjusting the Index due to taking out Ariarne Titmus
heat_index <- heat_index %>% 
  as.data.frame()%>%
  transpose()

final_index <- final_index %>%
  as.data.frame()%>%
  transpose()

min_diff_heat <- list()
min_diff_final <- list()
min_heat_name <- list()
min_final_name <- list()

for(i in c(1:8)){
  min_diff_heat[i] <- cumulative_time_heat[heat_index[1,i],i+1]
  min_heat_name[i] <- cumulative_time_heat[heat_index[1,i],1]
  min_diff_final[i] <- cumulative_time_final[final_index[1,i] + 1,i+1]
  min_final_name[i] <- cumulative_time_final[final_index[1,i] + 1,1]
}

closest_heat <- rbind(min_diff_heat, Ariarne_Titmus[1,19:26], min_heat_name) %>%
  as.data.frame()
rownames(closest_heat) <- c("Closest Competitor Time", "Arianrne Titmus Time", "Closest Competitor Name")

#Prepare the final data to plot
closest_final <- rbind(min_diff_final, Ariarne_Titmus[2,19:26], min_final_name) %>%
  as.data.frame()
rownames(closest_final) <- c("Closest Competitor Time", "Arianrne Titmus Time", "Closest Competitor Name")

closest_heat <- closest_heat %>% 
  transpose() %>%
  rename("Closest Competitor Time" = "V1" ,"Arianrne Titmus Time" = "V2", "Closest Competitor Name" = "V3") %>%
  mutate(Split_time = case_when(row_number() == 1 ~ "50m Split Time",
                                row_number() == 2 ~ "100m Split Time",
                                row_number() == 3 ~ "150m Split Time",
                                row_number() == 4 ~ "200m Split Time",
                                row_number() == 5 ~ "250m Split Time",
                                row_number() == 6 ~ "300m Split Time",
                                row_number() == 7 ~ "350m Split Time",
                                row_number() == 8 ~ "400m Split Time"))%>%
  mutate(`Lead or Lag` = case_when(`Arianrne Titmus Time` > `Closest Competitor Time` ~ "Lag",
                                   `Arianrne Titmus Time` < `Closest Competitor Time` ~ "Lead")) %>%
  mutate(`Time Difference` = abs(as.numeric(`Arianrne Titmus Time`) - as.numeric(`Closest Competitor Time`)))

closest_final <- closest_final %>% 
  transpose() %>%
  rename("Closest Competitor Time" = "V1" ,"Arianrne Titmus Time" = "V2", "Closest Competitor Name" = "V3") %>%
  mutate(Split_time = case_when(row_number() == 1 ~ "50m Split Time",
                                row_number() == 2 ~ "100m Split Time",
                                row_number() == 3 ~ "150m Split Time",
                                row_number() == 4 ~ "200m Split Time",
                                row_number() == 5 ~ "250m Split Time",
                                row_number() == 6 ~ "300m Split Time",
                                row_number() == 7 ~ "350m Split Time",
                                row_number() == 8 ~ "400m Split Time"))%>%
  mutate(`Lead or Lag` = case_when(`Arianrne Titmus Time` > `Closest Competitor Time` ~ "Lag",
                                   `Arianrne Titmus Time` < `Closest Competitor Time` ~ "Lead"))%>%
  mutate(`Time Difference` = abs(abs(as.numeric(`Arianrne Titmus Time`) - as.numeric(`Closest Competitor Time`))))

#Transform into Long Format
closest_heat <- pivot_longer(closest_heat, c("Closest Competitor Time","Arianrne Titmus Time"), names_to = "Competitor", values_to = "Time")

closest_final <- pivot_longer(closest_final, c("Closest Competitor Time","Arianrne Titmus Time"), names_to = "Competitor", values_to = "Time")

#Transform displayed Competitor name and arrange into a suitable format
closest_heat$`Closest Competitor Name` <- Mgsub(pattern = c("McINTOSH Summer","LEDECKY Kathleen","LI Bingjie"),replacement = c("Summer Mcintosh","Kathleen Ledecky","Bingjie Li"),closest_heat$`Closest Competitor Name`)

closest_heat <- closest_heat %>%
  mutate(`Closest Competitor Name` = ifelse(row_number() %% 2 == 0, "", `Closest Competitor Name`)) %>%
  mutate(`Lead or Lag` = ifelse(row_number() %% 2 == 0, "", `Lead or Lag`)) %>%
  mutate(`Time Difference` = ifelse(row_number() %% 2 == 0, "", round(as.numeric(`Time Difference`), 3))) %>%
  mutate(`Name` = ifelse(row_number() %% 2 == 0, "", "Ariarne Titmus")) %>%
  mutate(`Unit` = ifelse(row_number() %% 2 == 0, "", "seconds")) %>%
  mutate(`Closest Competitor` = ifelse(row_number() %% 2 == 0, "", "Closest Competitor:"))

closest_final$`Closest Competitor Name` <- Mgsub(pattern = c("McINTOSH Summer","LEDECKY Kathleen"),replacement = c("Summer Mcintosh","Kathleen Ledecky"),closest_final$`Closest Competitor Name`)

closest_final <- closest_final %>%
  mutate(`Closest Competitor Name` = ifelse(row_number() %% 2 == 0, "", `Closest Competitor Name`)) %>%
  mutate(`Lead or Lag` = ifelse(row_number() %% 2 == 0, "", `Lead or Lag`)) %>%
  mutate(`Time Difference` = ifelse(row_number() %% 2 == 0, "", round(as.numeric(`Time Difference`), 3))) %>%
  mutate(`Name` = ifelse(row_number() %% 2 == 0, "", "Ariarne Titmus")) %>%
  mutate(`Unit` = ifelse(row_number() %% 2 == 0, "", "seconds")) %>%
  mutate(`Closest Competitor` = ifelse(row_number() %% 2 == 0, "", "Closest Competitor:"))

#Split Time Plot
heat_time_plot <- ggplot(closest_heat,aes(y = Time, x = Competitor, fill = Competitor)) + 
  geom_col(width = 0.7, position = "dodge") + facet_wrap(~~factor(Split_time, levels = c('50m Split Time','100m Split Time','150m Split Time','200m Split Time','250m Split Time','300m Split Time','350m Split Time','400m Split Time')), scales = "free_y") + 
  ggtitle("Comparison of Split Time for every lap in Women 400m Freestyle Heat") + 
  geom_text(stat = "unique",nudge_x = -0.25, nudge_y = 0.3, aes(label = paste(`Closest Competitor`, `Closest Competitor Name`, "\n", `Name`, `Lead or Lag`, `Time Difference`, `Unit`)))

final_time_plot <- ggplot(closest_final,aes(y = Time, x = Competitor, fill = Competitor)) + 
geom_col(width = 0.7, position = "dodge") + facet_wrap(~factor(Split_time, levels = c('50m Split Time','100m Split Time','150m Split Time','200m Split Time','250m Split Time','300m Split Time','350m Split Time','400m Split Time')), scales = "free_y" ) + 
  ggtitle("Comparison of Split Time for every lap in Women 400m Freestyle Final") + 
  geom_text(stat = "unique",nudge_x = -0.25,nudge_y = 0.3, aes(label = paste(`Closest Competitor`, `Closest Competitor Name`, "\n", `Name`, `Lead or Lag`, `Time Difference`, `Unit`)))

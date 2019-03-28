
##### INSTALL AND LOAD PACKAGES #####
packages_list <- c('kableExtra',
                   'dplyr',
                   'ISOcodes',
                   'recommenderlab'
)

for (i in packages_list){
  if(!i%in%installed.packages()){
    install.packages(i, dependencies = TRUE, repos = "http://cran.us.r-project.org")
    library(i, character.only = TRUE)
    print(paste0(i, ' has been installed'))
  } else {
    print(paste0(i, ' is already installed'))
    library(i, character.only = TRUE)
  }
}


##### PARAMETERS #####
set.seed(100)     #Seed
nDivers <- 1000   #Number of divers
target_user <- 2

#Arbitrary list of countries
sel_countries <- ISO_3166_1[ISO_3166_1$Name %in% c('France', 'United States', 'United Kingdom',
                                                   'Spain', 'Italy', 'Belgium', 'Norway', 'China',
                                                   'Maldives', 'Germany'),'Alpha_3']

#Arbitrary list of dive types
dive_types <- c('Sand', 'Coral Garden', 'Wall', 'Wreck', 'Pinnacles', 'Canyon')

#Arbitrary list of critters
critters_list <- c('Manta Ray', 'Jellyfish', 'Octopus', 'Whale Shark', 'Reef Shark',
                   'Mandarin Fish', 'Mola Mola')


##### SITES TABLES #####

# List of dive sites from DiveBoard
sites <- read.csv('data/DiveBoard_spots.csv', sep = ',')
sites <- sites[sites$lat > 0 & sites$long > 70,]     #Filters sites with wrong coordinates
kable(head(sites, 10), caption = 'Dive Sites from DiveBoard') %>%
  kable_styling(bootstrap_options = "striped")

# Generate Maximum Depth (meters)
sites$max_depth <- rnorm(nrow(sites), mean = 25, sd = 5)
sites$max_depth <- round(sites$max_depth, 1)

# Generate Average Depth (meters)
sites$avg_depth <- sites$max_depth - runif(1, min = 0, max = sites$max_depth)
sites$avg_depth <- ifelse(sites$avg_depth <= 5, 5, sites$avg_depth)
sites$avg_depth <- round(sites$avg_depth, 1)

# Generate Visibility (meters)
sites$visibility <- sample(20, nrow(sites), replace = TRUE)

# Generate Current (from 1 to 5)
sites$current <- sample(5, nrow(sites), replace = TRUE)

# Generate Temperature at the Surface
sites$temp_top <- rnorm(nrow(sites), mean = 28, sd = 1)
sites$temp_top <- round(sites$temp_top, 1)

# Generate Temperature at the Bottom
sites$temp_bottom <- sites$temp_top - runif(1, min = 0, max = 2)
sites$temp_bottom <- round(sites$temp_bottom, 1)

# Generate Dive Types List
for (i in dive_types) {
  sites[i] <- sample(0:1, nrow(sites), replace = TRUE)
}

# Generate Critters List
for (i in critters_list) {
  sites[i] <- sample(0:1, nrow(sites), replace = TRUE)
}

kable(head(sites, 10), caption = 'Dive Sites Table') %>%
  kable_styling(bootstrap_options = "striped")


##### DIVERS TABLE #####

# Create Divers dataframe
divers <- data.frame(
  diver_id = seq(1,nDivers),                                   # Diver ID
  age = round(rnorm(nDivers, mean = 40, sd = 10), 0),          # Age
  certification = sample(4, nDivers, replace = TRUE),          # Certification level (from 1 to 4)
  ndives = sample(150, nDivers, replace = TRUE),               # Total number of dives
  max_depth = round(rnorm(nDivers, mean = 20, sd = 10), 1),    # Personal Record: Maximum Depth (meters)
  max_time = round(rnorm(nDivers, mean = 60, sd = 10), 0),     # Personal Record: Maximum Time (minutes)
  country = sample(sel_countries, nDivers, replace = TRUE)     # Country of Residence
)

# Make sure Maximum Depth is at least 10 meters
divers$max_depth <- ifelse(divers$max_depth <= 10, 10, divers$max_depth)

# Generate Cumulative Depth (meters)
divers$cum_depth <- as.integer(divers$ndives * rnorm(1, mean = 20, sd = 10))

# Generate Cumulative Time (minutes)
divers$cum_time <- as.integer(divers$ndives * rnorm(1, mean = 50, sd = 10))

# Generate Dive Types Preference List
for (i in dive_types) {
  divers[i] <- sample(0:1, nDivers, replace = TRUE)
}

# Generate Critters Preference List
for (i in critters_list) {
  divers[i] <- sample(0:1, nDivers, replace = TRUE)
}

kable(head(divers, 10), caption = 'Divers Table') %>%
  kable_styling(bootstrap_options = "striped")


##### USER LOGBOOK RATINGS ####
# Create Logbooks dataframe
logbooks <- data.frame()

# Generate Dive Ratings (from 1 to 5) for each dive of each diver
for (i in divers$diver_id){
  for (j in seq(1, divers[i, 'ndives'])){
    new_dive <- data.frame(diver_id = i, site_id = sample(sites$id, 1), rating = sample(1:5, 1))
    if (nrow(logbooks) == 0){
      logbooks <- new_dive
    }
    else {
      logbooks <- rbind(logbooks, new_dive)
    }
  }
}

kable(head(logbooks, 10), caption = 'Logbooks Table') %>%
  kable_styling(bootstrap_options = "striped")


##### HYBRID RECOMMENDER #####

# Split Users in Beginners, Confirmed and Pro groups
beginners <- divers[divers$ndives <= 20,]
kable(head(beginners, 10), caption = 'Beginners Divers') %>%
  kable_styling(bootstrap_options = "striped")

confirmed <- divers[(divers$ndives > 20) & (divers$ndives <= 100),]
kable(head(confirmed, 10), caption = 'Confirmed Divers') %>%
  kable_styling(bootstrap_options = "striped")

pro <- divers[divers$ndives > 100,]
kable(head(pro, 10), caption = 'Pro Divers') %>%
  kable_styling(bootstrap_options = "striped")

# Convert Logbooks to Real Rating Matrices
logbooks_beginners <- logbooks[logbooks$diver_id %in% beginners$diver_id,]
logbooks_beginners_matrix <- as(logbooks_beginners, "realRatingMatrix")

logbooks_confirmed <- logbooks[logbooks$diver_id %in% confirmed$diver_id,]
logbooks_confirmed_matrix <- as(logbooks_confirmed, "realRatingMatrix")

logbooks_pro <- logbooks[logbooks$diver_id %in% pro$diver_id,]
logbooks_pro_matrix <- as(logbooks_pro, "realRatingMatrix")

# Define Evaluation Schemes
split_beginners <- evaluationScheme(logbooks_beginners_matrix,
                                    method="cross",
                                    train=0.75,
                                    goodRating = 4,
                                    given=-1)

split_confirmed <- evaluationScheme(logbooks_confirmed_matrix,
                                    method="cross",
                                    train=0.75,
                                    goodRating = 4,
                                    given=-1)

split_pro <- evaluationScheme(logbooks_pro_matrix,
                                    method="cross",
                                    train=0.75,
                                    goodRating = 4,
                                    given=-1)

# Define recommendation models
rec_beginners_1 <- Recommender(getData(split_beginners, "train"), "POPULAR")
rec_beginners_2 <- Recommender(getData(split_beginners, "train"), "IBCF")
rec_beginners_3 <- Recommender(getData(split_beginners, "train"), "RANDOM")
ensemble_beginners <- HybridRecommender(rec_beginners_1, rec_beginners_2, rec_beginners_3,
                                        weights = c(0.5, 0.3, 0.2))

rec_confirmed_1 <- Recommender(getData(split_confirmed, "train"), "POPULAR")
rec_confirmed_2 <- Recommender(getData(split_confirmed, "train"), "UBCF")
rec_confirmed_3 <- Recommender(getData(split_confirmed, "train"), "RANDOM")
ensemble_confirmed <- HybridRecommender(rec_confirmed_1, rec_confirmed_2, rec_confirmed_3,
                                        weights = c(0.3, 0.4, 0.3))

rec_pro_1 <- Recommender(getData(split_pro, "train"), "IBCF")
rec_pro_2 <- Recommender(getData(split_pro, "train"), "RERECOMMEND")
rec_pro_3 <- Recommender(getData(split_pro, "train"), "RANDOM")
ensemble_pro <- HybridRecommender(rec_pro_1, rec_pro_2, rec_pro_3,
                                  weights = c(0.4, 0.3, 0.3))

# Predict Top 15 Dive Recommendations
pred_ensemble_beginners <- predict(ensemble_beginners, getData(split_beginners,"known"), type="topNList", n=15)
pred_ensemble_confirmed <- predict(ensemble_confirmed, getData(split_confirmed,"known"), type="topNList", n=15)
pred_ensemble_pro <- predict(ensemble_pro, getData(split_pro,"known"), type="topNList", n=15)

top_15_ensemble_beginner <- as.data.frame(as(pred_ensemble_beginners,'list')[target_user], col.names = 'site_id')
top_15_ensemble_confirmed <- as.data.frame(as(pred_ensemble_confirmed,'list')[target_user], col.names = 'site_id')
top_15_ensemble_pro <- as.data.frame(as(pred_ensemble_pro,'list')[target_user], col.names = 'site_id')

top_15_ensemble_beginner <- merge(top_15_ensemble_beginner, sites, by.x = 'site_id', by.y = 'id')
top_15_ensemble_confirmed <- merge(top_15_ensemble_confirmed, sites, by.x = 'site_id', by.y = 'id')
top_15_ensemble_pro <- merge(top_15_ensemble_pro, sites, by.x = 'site_id', by.y = 'id')

kable(head(top_15_ensemble_beginner, 10), caption = paste('Recommendations for Beginner Diver', target_user)) %>%
  kable_styling(bootstrap_options = "striped")

kable(head(top_15_ensemble_confirmed, 10), caption = paste('Recommendations for Confirmed Diver', target_user)) %>%
  kable_styling(bootstrap_options = "striped")

kable(head(top_15_ensemble_pro, 10), caption = paste('Recommendations for Pro Diver', target_user)) %>%
  kable_styling(bootstrap_options = "striped")


##### CONTENT-BASED RECOMMENDER #####

# Prepare Sites dataset
sites_light <- sites
sites_light <- sites %>% select(-id, -name,-lat,-long,
                                -location_name, -region_name, -country_name)
rownames(sites_light) <- sites$id

# Collect Target User's Dive Site Ratings
target_user_site_ratings <- logbooks[logbooks$diver_id == target_user,'rating']
names(target_user_site_ratings) <- logbooks[logbooks$diver_id == target_user,'site_id']
sites_in_target_user_logbook <- names(target_user_site_ratings)

target_user_sites_light <- sites_light[sites_in_target_user_logbook,]

# Predictions based on Linear Regression Model for Target User
target_user_model <- lm(target_user_site_ratings~.,cbind(target_user_sites_light,target_user_site_ratings))
predictions <- predict(target_user_model, target_user_sites_light)

# Get predictions for Target User
targeted_user_top_15 <- sort(predictions, decreasing = T)[1:15]
targeted_user_top_15 <- as.data.frame(targeted_user_top_15)
colnames(targeted_user_top_15) <- 'rating'
targeted_user_top_15$site_id <- rownames(targeted_user_top_15)

targeted_user_top_15 <- merge(targeted_user_top_15, sites, by.x = 'site_id', by.y = 'id')
targeted_user_top_15 <- targeted_user_top_15[order(targeted_user_top_15$rating, decreasing = TRUE),]
targeted_user_top_15$rating <- NULL
rownames(targeted_user_top_15) <- NULL
kable(head(targeted_user_top_15, 10), caption = paste('Content-Based Recommendations for Target Diver', target_user)) %>%
  kable_styling(bootstrap_options = "striped")


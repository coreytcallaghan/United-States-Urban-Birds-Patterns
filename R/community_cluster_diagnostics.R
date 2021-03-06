library(dplyr)
library(tidyr)
library(ggplot2)

source("R/community_cluster_diagnostics_funs.R")

# load allocations calculate in community_cluster_fit-k-means.R
allocations <- readRDS("Outputs/cluster_allocations/bcr_kmeans_allocations.rds")

# load the localities that were used for clustering
localities_list <- lapply(allocations, function(x) x[["localities"]])



# inspect the sum of squares ----------------------------------------------

# flatten
allocations_diagnostics <- bind_rows(lapply(allocations, flatten_list), .id = "BCR") # this is where the BCR unlisting is done

# add information criterion
allocations_diagnostics_summary <- allocations_diagnostics %>%
  mutate(AIC = total_within_ss + (2 * n_vars * k),
         BIC = total_within_ss + (log(n_obs) * n_vars * k))

# go long for plotting
allocations_diagnostics_plot <- allocations_diagnostics_summary %>%
  select(BCR, k, total_within_ss, AIC, BIC) %>%
  gather(metric, value, total_within_ss:BIC)

ggplot(allocations_diagnostics_plot, aes(x = k, group = metric)) +
  geom_line(aes(y = value, colour = metric)) +
  facet_wrap(~BCR, scales = "free")

allocations_diagnostics_plot %>%
  filter(metric == "AIC") %>%
  mutate(BCR = gsub("_", " ", .$BCR)) %>%
  mutate(BCR = gsub("WEST GULF COASTAL PLAIN OUACHITAS", "WEST GULF COASTAL PLAIN/OUACHITAS", .$BCR)) %>%
  mutate(BCR = gsub("SOUTHERN ROCKIES COLORADO PLATEAU", "SOUTHERN ROCKIES/COLORADO PLATEAU", .$BCR)) %>%
  mutate(BCR = gsub("LOWER GREAT LAKES ST LAWRENCE PLAIN", "LOWER GREAT LAKES/ST. LAWRENCE PLAIN", .$BCR)) %>%
  mutate(BCR = gsub("NEW ENGLAND MID ATLANTIC COAST", "NEW ENGLAND/MID-ATLANTIC COAST", .$BCR)) %>%
ggplot(., aes(x = k, group = metric)) +
  geom_line(aes(y = value, colour = metric)) +
  facet_wrap(~BCR, scales = "free", labeller = labeller(BCR = label_wrap_gen(18)))+
  xlab("k")+
  ylab("value")+
  guides(color=FALSE)+
  theme_bw()+
  theme(strip.text.x = element_text(size = 6, colour = "black"))

ggsave(file="H:/Dissertation/Dissertation Chapters/Data Chapters/United States Urban Bird Patterns/Submissions/Landscape Ecology/Appendix S8/cluster_aics.png",
       width=9.5, height=8, units="in", dpi=300)


ggplot(filter(allocations_diagnostics_plot, metric == "total_within_ss"), aes(x = k, group = metric)) +
  geom_line(aes(y = value, colour = metric)) +
  facet_wrap(~BCR, scales = "free")

### looks like AIC is more informative at this point
### will try re-run with a distance metric on the data?



# choose best clusters ----------------------------------------------------

min_AIC_data <- allocations_diagnostics_summary %>%
  group_by(BCR) %>%
  filter(AIC == min(AIC))

min_AIC_clusters <- purrr::map2(allocations, min_AIC_data$k, retreive_k_clusters)



# compare communities to land cover classification ------------------------

# join the data together
clusters_landcover <- lapply(names(min_AIC_clusters), join_lc_data, min_AIC_clusters, localities_list)
names(clusters_landcover) <- names(min_AIC_clusters)

# entropy values: examine distriubtion of assembleges
# low entropy indicates less even distribution among groups (often indicates gruops with low or no membership)

# urban_diff values: examine whether (proportionally) more of the communities are in non-urban areas
# positive values will mean more proportional membership of sites to the non-urban component


#### urban / non-urban comparison

urban_entropy <- gather(bind_rows(lapply(clusters_landcover, calculate_entropy, type = "urban"),
                                  .id = "BCR"), "zone", "value", -BCR)

ggplot(urban_entropy, aes(y = value, x = zone)) +
  geom_boxplot() +
  geom_point(aes(colour = BCR)) +
  geom_line(aes(group = BCR))

summary(nlme::lme(fixed = value ~ zone, random = ~ 1 | BCR, data = urban_entropy))


urban_urbandiff <- bind_rows(lapply(clusters_landcover, calculate_urban_diff, type = "urban"),
                             .id = "BCR")

ggplot(urban_urbandiff, aes(y = urban_diff, x = BCR)) +
  #geom_violin() +
  geom_point(alpha = 0.5, size = 3) +
  geom_hline(yintercept = 0, colour = "red") +
  theme_classic()


#### land cover comparison

# entropy values - examine distriubtion of assembleges
landcover_entropy <- gather(bind_rows(lapply(clusters_landcover, calculate_entropy, type = "landcover"), 
                                      .id = "BCR"),
                            "zone", "value", -BCR) %>%
  filter(zone %in% c("Natural.Green.Area", "Urban.Green.Area")) %>%
  mutate(zone = gsub("Natural.Green.Area", "Natural Green Area", .$zone)) %>%
  mutate(zone = gsub("Urban.Green.Area", "Urban Green Area", .$zone)) %>%
  mutate(BCR = gsub("_", " ", .$BCR)) %>%
  mutate(BCR = gsub("WEST GULF COASTAL PLAIN OUACHITAS", "WEST GULF COASTAL PLAIN/OUACHITAS", .$BCR)) %>%
  mutate(BCR = gsub("SOUTHERN ROCKIES COLORADO PLATEAU", "SOUTHERN ROCKIES/COLORADO PLATEAU", .$BCR)) %>%
  mutate(BCR = gsub("LOWER GREAT LAKES ST LAWRENCE PLAIN", "LOWER GREAT LAKES/ST. LAWRENCE PLAIN", .$BCR)) %>%
  mutate(BCR = gsub("NEW ENGLAND MID ATLANTIC COAST", "NEW ENGLAND/MID-ATLANTIC COAST", .$BCR))

ggplot(landcover_entropy, aes(y = value, x = zone)) +
  geom_violin()+
  stat_summary(fun.y=mean, geom="point", size=6, shape=15, alpha=0.7, color="red", aes(color=BCR))+
  theme_classic()+
  ylab("Shannon entropy of cluster assignments")+
  xlab("")+
  coord_flip()+
  theme(axis.text.x=element_text(size=16))+
  theme(axis.text.y=element_text(size=16))+
  theme(axis.title.x = element_text(size=14))+
  theme(axis.title.y=element_text(size=14))

ggsave(filename="H:/Dissertation/Dissertation Chapters/Data Chapters/United States Urban Bird Patterns/Submissions/Landscape Ecology/Figures/cluster_assignments.png",
       height=4, width=6, units="in")

## stats to report for paper
landcover_entropy %>%
  group_by(zone) %>%
  summarise(mean=mean(value),
            sd=sd(value))

urban <- landcover_entropy %>%
  filter(zone == "Urban Green Area") %>%
  .$value

natural <- landcover_entropy %>%
  filter(zone == "Natural Green Area") %>%
  .$value


var.test(urban, natural) 

t.test(urban, natural, var.equal=FALSE, paired=FALSE)

summary(nlme::lme(fixed = value ~ zone, random = ~ 1 | BCR, data = landcover_entropy))

# urban_diff values - examine whether (proportionally) more of the communities are in non-urban areas
landcover_urbandiff <- bind_rows(lapply(clusters_landcover, calculate_urban_diff, type = "landcover"),
                                 .id = "BCR")

library(forcats)
landcover_urbandiff %>%
  group_by(BCR) %>%
  summarise(mean=mean(urban_diff)) %>%
  inner_join(., landcover_urbandiff, by="BCR") %>%
  arrange(mean) %>%
  mutate(BCR = gsub("_", " ", .$BCR)) %>%
  mutate(BCR = gsub("WEST GULF COASTAL PLAIN OUACHITAS", "WEST GULF COASTAL PLAIN/OUACHITAS", .$BCR)) %>%
  mutate(BCR = gsub("SOUTHERN ROCKIES COLORADO PLATEAU", "SOUTHERN ROCKIES/COLORADO PLATEAU", .$BCR)) %>%
  mutate(BCR = gsub("LOWER GREAT LAKES ST LAWRENCE PLAIN", "LOWER GREAT LAKES/ST. LAWRENCE PLAIN", .$BCR)) %>%
  mutate(BCR = gsub("NEW ENGLAND MID ATLANTIC COAST", "NEW ENGLAND/MID-ATLANTIC COAST", .$BCR)) %>%
ggplot(., aes(y = urban_diff, x = fct_inorder(BCR))) +
  geom_point(alpha = 0.5, size = 3) +
  geom_hline(yintercept = 0, colour = "red") +
  theme_classic()+
  coord_flip()+
  ylab("Proportional difference")+
  xlab("BCR")

ggsave(file="H:/Dissertation/Dissertation Chapters/Data Chapters/United States Urban Bird Patterns/Submissions/Landscape Ecology/Appendix S8/proportional_difference.png",
       width=8, height=5, units="in", dpi=300)



# calculate per-cluster species metrics (i.e. community metrics) ------------------------

clusters_metrics <- lapply(names(min_AIC_clusters), calculate_cluster_metrics,
                           min_AIC_clusters, localities_list)
names(clusters_metrics) <- names(min_AIC_clusters)

cluster_metrics_df <- bind_rows(clusters_metrics, .id = "BCR") %>%
  mutate(cluster = as.integer(cluster))

# join with other data...
cluster_metrics_urbandiff <- inner_join(urban_urbandiff, cluster_metrics_df)
cluster_metrics_lcdiff <- inner_join(landcover_urbandiff, cluster_metrics_df)
# check for trends...



plot(urban_diff~richness, data = cluster_metrics_urbandiff)
plot(urban_diff~richness, data = cluster_metrics_lcdiff)
plot(urban_diff~diversity, data = cluster_metrics_urbandiff)
plot(urban_diff~diversity, data = cluster_metrics_lcdiff)


## Make two plots for appendix for paper
ggplot(cluster_metrics_lcdiff, aes(x=urban_diff, y=richness))+
  geom_point()+
  theme_classic()+
  xlab("Proportional difference")+
  ylab("Total richness")


ggsave(file="H:/Dissertation/Dissertation Chapters/Data Chapters/United States Urban Bird Patterns/Submissions/Landscape Ecology/Appendix S8/richness_proportional.png",
       width=7, height=6, units="in", dpi=300)

ggplot(cluster_metrics_lcdiff, aes(x=urban_diff, y=diversity))+
  geom_point()+
  theme_classic()+
  xlab("Proportional difference")+
  ylab("Total diversity")












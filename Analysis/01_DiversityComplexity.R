##############
# Analysis of Life History Webs
# Script 1) Diversity-complexity relationships and overlap for: 
# Clegg, Ali and Beckerman 2018: The Impact of Intraspecific Variation on Food Web Structure
##############
# Doi:
# Last edited 01.02.2017
# Copyright (c) 2017 the authors
##############
# Preparation ect.
# Clear workspace
rm(list = ls())
set.seed(1)

#Loading Packages
library(cheddar)
library(tidyverse)
library(reshape2)
library(gridExtra)

#Loading LS webs
LS_paths <- paste0("../Data/LS_Webs/",list.files("../Data/LS_Webs/"))
LS_webs <- vector("list", length(LS_paths))
for(i in 1:length(LS_paths)){
  LS_webs[[i]] <- LoadCommunity(LS_paths[i])
}

#Loading non-LS webs
non_LS_paths <- paste0("../Data/Non_LS_Webs/",list.files("../Data/Non_LS_Webs/"))
non_LS_webs <- vector("list", length(non_LS_paths))
for(i in 1:length(non_LS_paths)){
  non_LS_webs[[i]] <- LoadCommunity(non_LS_paths[i])
}

##############
#Q1a) How does LH influence Diversity-Complexity Relationships

#Get DF with Nodes and Links
Nodes <- log(c(sapply(LS_webs,NumberOfNodes),sapply(non_LS_webs,NumberOfNodes)))
Links <- log(c(sapply(LS_webs,NumberOfTrophicLinks),sapply(non_LS_webs,NumberOfTrophicLinks)))
names <- c(sapply(LS_webs,function(x) x$properties$title),sapply(non_LS_webs,function(x) x$properties$title))
LS <- c(sapply(LS_webs,function(x) x$properties$LS),rep("other",length(non_LS_webs)))
Web <- c(gsub(" Lifestage| Taxanomic","",sapply(LS_webs,function(x) x$properties$title)),
         rep("other",length(non_LS_webs)))

NL_all <- data.frame(names = names,web = Web ,LS = LS, nodes = Nodes, links = Links)

# Regression
# Log(link) ~ log(Nodes)
reg_data <- NL_all[NL_all$LS != "LS",]
reg_data$nodes <- reg_data$nodes
reg_data$links <- reg_data$links

NL_model <- lm(links~nodes,data = reg_data)

reg_data$pred <- predict(NL_model)

# Plotting
# Defining Colour Vars
cbPalette <- c("#D55E00", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2")
names(cbPalette) <- (unique(Web))

NvL <- ggplot(NL_all,aes(x = (nodes), y = (links), colour = web))+
        geom_point(size = 3)+
        geom_line(data = NL_all[NL_all$web != "other",])+
        scale_color_manual(values = cbPalette)+labs(x = "Log (nodes)", y = "Log (links)")+
        theme_classic() +
        theme(legend.position = c(0.9,0.1),legend.justification = c(1,0),legend.title = element_blank())+
        geom_line(data = reg_data,aes(x=nodes,y=pred,group = NULL,colour = NULL))

##############
# Q1b) How is this affected by LS overlap?
# Functions
# Define similarity
jaccard <- function(s1,s2){
  length(intersect(s1,s2))/length(union(s1,s2))
}

Overlaps <- function(community){
  print(community$properties$title)
  T_links <- community$trophic.links
  T_links$taxa.ID.Prey <- 0
  T_links$taxa.ID.Pred <- 0

  #get list of multi LS species/groups
  multi_LS <- duplicated(community$nodes$taxa.ID) | duplicated(community$nodes$taxa.ID,fromLast = T)
  multi_LS <- (table(community$nodes$taxa.ID[multi_LS]))

  mean_con <- vector(length = length(multi_LS))
  mean_res <- vector(length = length(multi_LS))

  #itterate through these species/groups
  for(i in 1:length(multi_LS)){
    #get the node names of each stage
    names <- community$nodes$node[community$nodes$taxa.ID == names(multi_LS)[i]]
    #create a list to store the links each stage is part of
    Con_links <- vector("list", multi_LS[i])
    Res_links <- vector("list", multi_LS[i])
    #get the links
    for(j in 1:multi_LS[i]){
      Res_links[[j]] <- T_links[T_links$resource == names[j],]
      Con_links[[j]]<- T_links[T_links$consumer == names[j],]
    }
    #get indexs for each pair
    pair_indexes <- combn(1:multi_LS[i],2)

    #get similarity as consumer and resource
    con_jacc <- vector(l = ncol(pair_indexes))
    res_jacc <- vector(l = ncol(pair_indexes))

    for(j in 1:ncol(pair_indexes)){
      one <- Con_links[[pair_indexes[1,j]]]$resource
      two <- Con_links[[pair_indexes[2,j]]]$resource
      con_jacc[j] <- jaccard(one,two)

      one <- Res_links[[pair_indexes[1,j]]]$consumer
      two <- Res_links[[pair_indexes[2,j]]]$consumer
      res_jacc[j] <- jaccard(one,two)
      #check for nan
      if(is.nan(con_jacc[j])){ con_jacc[j]<-0}
      if(is.nan(res_jacc[j])){ res_jacc[j]<-0}
    }
    mean_con[i] <- mean(con_jacc)
    mean_res[i] <- mean(res_jacc)
  }

  results <- c(mean(mean_con),mean(mean_res))
  names(results) <- c("Consumer","Resource")
  return(results)
}
#Get LS webs only
Overlap_Webs <- LS_webs[sapply(LS_webs,function(x) x$properties$LS == "LS")]
#get overlaps
Overlaps_data <- sapply(Overlap_Webs,Overlaps)
#add web names
colnames(Overlaps_data) <- sapply(Overlap_Webs,function(x) x$properties$title)
#reformat the data
Overlaps_data <- melt(Overlaps_data)
Overlaps_data$Var2 <- gsub(Overlaps_data$Var2 ,pattern = " Lifestage",replacement = "")
colnames(Overlaps_data) <- c("overlap.type","web","overlap")

#calculate the ratios
ratios <- NL_all %>%
  filter(LS != 'other') %>%
  group_by(web) %>%
  do(data.frame(nodes = max(.$nodes)-min(.$nodes), links = max(.$links)-min(.$links)))

ratios$ratios <- ratios$links/ratios$nodes
ratios$nodes <- NULL ; ratios$links <- NULL

#add to NL data
Overlaps_data <- NL_all %>%
    filter(LS != 'other') %>%
    merge(.,Overlaps_data) %>%
    merge(.,ratios)

Overlaps_data %>%
  select(overlap.type, overlap, ratios) %>%
  group_by(overlap.type) %>%
  distinct() %>%
  do(data.frame(stat = cor.test(.$overlap,.$ratios)[1],
                para = cor.test(.$overlap,.$ratios)[2],
                stat = cor.test(.$overlap,.$ratios)[3],
                para = cor.test(.$overlap,.$ratios)[4]))

cor.test(c(1,2,3),c(2,4,9))[5]

OvS.plot <- ggplot(Overlaps_data,aes(x = overlap, y = ratios, colour = web))+
  geom_point(size = 3)+
  labs(x = "Overlap", y = "ΔL / ΔS")+
  theme_classic() +
  theme(legend.position =  "none",strip.background = element_blank())+
  facet_wrap(~overlap.type,nrow=2, scales = 'free')+
  xlim(0,0.7)+
  scale_color_manual(values = cbPalette)

ggsave(grid.arrange(NvL,OvS.plot,ncol=2),filename = "../Figs/Fig1_SvL.pdf")

##############

#General Web stats

#proportion of stages with LS information

prop.LS <- function(community){
  return(sum(table(community$nodes$taxa.ID) > 1) /
         length(table(community$nodes$taxa.ID)))
}

proportions <- sapply(Overlap_Webs,prop.LS)
names(proportions) <- (sapply(Overlap_Webs,function(x) x$properties$title))

proportions

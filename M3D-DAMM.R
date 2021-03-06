#M3D-DAMM

#FIGURE OUT THE DIFUSION AND NET EMISSIONS and then, CORRECT UNITS

library(FME)

df <- read.csv("Flux.csv", header=TRUE) 
#data = dplyr::filter(.data = df,topo %in% c("Ridge"))
#data = dplyr::filter(.data = df,topo %in% c("Slope"))
data = dplyr::filter(.data = df,topo %in% c("Valley"))
data = df[,"CH4"]

#Set x-axes
xa09 = seq(57,354, length.out = length(data))      
xb09 = seq(57,354, length.out = 298) 

#Load parameters and input data
parameters <- read.csv(paste0(getwd(),"/parameters.csv"))
inputdata <- read.csv(paste0(getwd(),"/inputdata.csv"))

#Set up model run
p = parameters$M3D_DAMM

SoilC <- 4.83 #percentage

k <- 10 # CHANGE #k from Wendy's paper and SoilC from Christine's paper
SoilC_Q10 <- 2 #CHANGE

rAer <- 1 #CHANGE
kAer_O2 <- k #CHANGE
AerDecomp_Q10 <- 2 #CHANGE

#Set up model function
Model <- function (p, times=seq(57,354)) { #Change the time step
  derivs <- function(t,s,p) { #t = time, s = state, p = pars
    with(as.list(c(s,p)), {
k_Ace <- p[1]
AceProd_max <- p[2]
k_ACeProdO2 <- p[3]
H2ProdAce_max <- p[4]
kH2Prod_Ace <- p[5]
kCO2Prod_Ace <- p[6]
GrowR_H2Methanogens <- p[7]
DeadR_H2Methanogens <- p[8]
Y_H2Methanogens <- p[9]
GrowR_AceMethanogens <- p[10]
DeadR_AceMethanogens <- p[11]
Y_AceMethanogens <- p[12]
GrowR_Methanotrophs <- p[13]
DeadR_Methanotrophs <- p[14]
Y_Methanotrophs <- p[15]
AceProd_Q10 <- p[16]
ACMin_Q10 <- p[17]
AceH2min <- p[18]
CH4H2min <- p[19]
KH2Prod_CH4 <- p[20]
KCO2Prod_CH4 <- p[21]
H2CH4Prod_Q10 <- p[22]
KCH4Prod_Ace <- p[23]
#KCH4Prod_O2 <- p[24] #CHECK 
H2AceProd_Q10 <- p[24] #CHANGE
CH4Prod_Q10 <- p[25]
rCH4Prod <- p[26]
KCH4Oxid_CH4 <- p[27]
KCH4Oxid_O2 <- p[28]
CH4Oxid_Q10 <- p[29]
rCH4Oxid <- p[30]

Porosity = 1 - (1.0557/2.65) #bd=0.557 pd=2.52
Dliq <- 1/(Porosity^3)
CO2airfrac = 385.5 * 1e-6 * 1.01e+5 # ppm co2 concentration in air converted to mol / m3 dry air
CH4airfrac = 1.8 * 1e-6 * 1.01e+5 # ppm ch4 concentration in air converted to mol / m3 dry air
O2airfrac = 0.209*10^(6) * 1e-6 * 1.01e+5  # ppm o2 concentration in air converted to mol / m3 dry air  
H2airfrac = 0.0000005*10^(6) * 1e-6 * 1.01e+5  # ppm h2 concentration in air converted to mol / m3 dry air 

a_4_3 <- ((Porosity-SoilM(t)/100)^(4/3))*(((SoilT(t))/273.15)^1.75)
a_4_3_max <- ((Porosity-0/100)^(4/3))*(((25+273.15)/273.15)^1.75)
Dgas <- 1/a_4_3_max

CO2Dif <- Dgas * CO2airfrac * a_4_3
CH4Dif <- Dgas * CH4airfrac * a_4_3
O2Dif <- Dgas * O2airfrac * a_4_3
H2Dif <- Dgas * H2airfrac * a_4_3

Depth <- 0.1#meter #NEED TO UPDATE FOR THE DIFFUSION MODULE OF DAMM

#Environmenal Controls for pH 
soilpH = -1 * log10((10 ** (-soilpH) + 0.0042 * 0.001 * Ace))
pHmin <- 3
pHmax <- 11
pHopt <- 7 
f_pH <-  (soilpH - pHmin) * (soilpH - pHmax) / ((soilpH - pHmin) * (soilpH - pHmax) - (soilpH - pHopt) * (soilpH - pHopt))

AceProd = ifelse(SoilM(t)<0.375, 
       AceProd_max * DOC * (DOC/(DOC+k_Ace)) * ACMin_Q10^((SoilT(t)-25)/10) * f_pH, #<0.375 threshold
       AceProd_max * DOC * (O2(t)/(O2(t)+k_ACeProdO2)) * AceProd_Q10^((SoilT(t)-25)/10) * f_pH #>0.375 threshold
       )

CO2Prod_AC =  (1/2) * AceProd 

H2Prod_AC = ifelse(SoilM(t)<0.375, 
                   (1/6) * AceProd, #<0.375 threshold
                 0#>0.375 threshold
                  )

fr_Ace =  (1/(1+ exp(-5000000*(H2-AceH2min))))
AceProd_H2 =   H2ProdAce_max * (H2/(H2+kH2Prod_Ace)) * (CO2/(CO2+kCO2Prod_Ace)) * H2AceProd_Q10^((SoilT(t)-25)/10) * f_pH * fr_Ace

fr_CH4 = ifelse(H2<((CH4H2min+AceH2min)/2),
                (1/(1+ exp(-5000000*(H2-CH4H2min)))),
                (1/(1+ exp(5000000*(H2-AceH2min)))) 
               )
CH4Prod_H2 =  (GrowR_H2Methanogens/Y_H2Methanogens) * H2Methanogens * (H2/(H2+KH2Prod_CH4)) * (CO2/(CO2+KCO2Prod_CH4)) * H2CH4Prod_Q10^((SoilT(t)-25)/10) * f_pH * fr_CH4

H2Cons = 4 * (AceProd_H2 + CH4Prod_H2)

Ace_av =  Ace*Dliq*(SoilM(t)/100)^(3.0) #From DAMM
AceCons =  (GrowR_AceMethanogens/Y_AceMethanogens) * AceMethanogens * (Ace_av/(Ace_av+KCH4Prod_Ace)) * CH4Prod_Q10^((SoilT(t)-25)/10) * f_pH

CH4Prod =  rCH4Prod * (1 - Y_AceMethanogens) * AceCons

CH4Oxid =  (GrowR_Methanotrophs/Y_Methanotrophs) *Methanotrophs * (CH4/(CH4+KCH4Oxid_CH4)) * (O2(t)/(O2(t)+KCH4Oxid_O2)) * CH4Oxid_Q10^((SoilT(t)-25)/10) * f_pH

AerO2Cons =  rAer * DOC * (O2(t)/ (O2(t)+kAer_O2)) * AerDecomp_Q10^((SoilT(t)-25)/10) * f_pH
CH4O2Cons =  rCH4Oxid * CH4Oxid

CO2Prod =  CO2Prod_AC + CH4Prod + CH4Oxid
CO2Cons =  2 * AceProd_H2 + CH4Prod_H2

AceMethanogenGrowth =  Y_AceMethanogens * AceCons 
AceMethanogenDying =  DeadR_AceMethanogens * AceMethanogens
H2MethanogenGrowth =  Y_H2Methanogens * 4 * CH4Prod_H2 #CHECK 
H2MethanogenDying =  DeadR_H2Methanogens * H2Methanogens
MethanotrophsGrowth =  Y_Methanotrophs * CH4Oxid
MethanotrophsDying =  DeadR_Methanotrophs * Methanotrophs

#Available carbon 
dDOC = SoilC * k * SoilC_Q10^((SoilT(t)-25)/10) - AceProd - CO2Prod_AC 

#H2 Dynamics
dH2 = H2Prod_AC - H2Cons + H2Dif # ADD EQUATION USING DAMM 

#Homoacetogenesis
dAce = AceProd + AceProd_H2 - AceCons  #NEED TO ADD DIFFUSION EQUATION FOR ACETATE USING DAMM

#Methane
dCH4 = CH4Prod + CH4Prod_H2 - CH4Oxid + CH4Dif # ADD WITH DAMM MODEL

#Oxygen
dO2 =  AerO2Cons - CH4O2Cons + O2Dif # ADD WITH DAMM MODEL

#Carbon Dioxide
dCO2 = CO2Prod - CO2Cons + CO2Dif # ADD WITH DAMM MODEL

#Microbial Dynamics
dAceMethanogens = AceMethanogenGrowth - AceMethanogenDying
dH2Methanogens = H2MethanogenGrowth - H2MethanogenDying
dMethanotrophs = MethanotrophsGrowth - MethanotrophsDying

#Soil pH Dynamics
dsoilpH = soilpH

return(list(c(dDOC, dH2, dAce, dCH4, dO2, dCO2, 
              dAceMethanogens, dH2Methanogens, dMethanotrophs, dsoilpH)))
    })
  }
  
#CHANGE INITIAL STATES  
s <- c(DOC = 1.9703, H2 = 0.1970, Ace = 65.25 , CH4 = 2.1917,
       O2 = 0.0020, CO2 = 0.0011, AceMethanogens = 0.0339, 
       H2Methanogens = 0.0339, Methanotrophs = 0.0339, soilpH=6) #initial states

SoilT <- approxfun(input$DOY, input$SoilT) #temperature input function
SoilM <- approxfun(input$DOY, input$SoilM) #moisture input function
O2 <- approxfun(input$DOY, input$O2) #moisture input function

output <- ode(y = s, times=times, func=derivs, parms = p) #solve ode, return output
return(as.data.frame(cbind(time = output[1:297,1], 
      DOC = output[1:297,"DOC"], H2 = output[1:297,"H2"], 
      Ace = output[1:297,"Ace"], CH4 = output[1:297,"CH4"], 
      O2 = output[1:297,"O2"], CO2 = output[1:297,"CO2"], 
      AceMethanogens = output[1:297,"AceMethanogens"],
      H2Methanogens = output[1:297,"H2Methanogens"],
      Methanotrophs = output[1:297,"Methanotrophs"],
      soilpH = output[1:297,"soilpH"])))
}

#Run model
out <- NULL                           #initalize output matrix
ptm <- proc.time()                    #start timer
input <- list(inputdata)[[1]]         #define input data
out <- as.data.frame(Model(p))        #run model
proc.time() - ptm                     #end timer

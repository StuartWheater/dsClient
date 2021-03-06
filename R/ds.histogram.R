#' 
#' @title Generates a histogram plot
#' @description This function plots a histogram without outliers.
#' @details It calls a datashield server side function that produces the
#' histogram objects to plot. The objects to plot do not contain bins with
#' counts smaller than the allowed threshold. The function allows for the user to plot 
#' disctinct histograms (one for each study) or a combine histogram that merges the single plots.
#' @param x a charcater, the name of the vector of values for which the histogram is desired.
#' @param type a character which represent the type of graph to display.
#' If \code{type} is set to 'combine', a histogram that merges the single
#' plot is displayed. Each histogram is plotted separately if If \code{type}
#' is set to 'split'.
#' @param datasources a list of opal object(s) obtained after login in to opal servers;
#' these objects hold also the data assign to R, as \code{dataframe}, from opal datasources.
#' @return one or more histogram objects and plots depending on the argument \code{type}
#' @author Gaye, A.
#' @export
#' @examples {
#'
#'   # load that contains the login details
#'   data(logindata)
#'   library(opal)
#'
#'   # login and assign specific variable(s)
#'   myvar <- list('LAB_TSC', 'LAB_HDL')
#'   opals <- datashield.login(logins=logindata,assign=TRUE,variables=myvar)
#'
#'   # Example 1: plot a combined histogram of the variable 'LAB_TSC'  default behaviour
#'   ds.histogram(x='D$LAB_TSC')
#'
#'   # Example 2: Plot the histograms of LAB_TSC separately (one per study)
#'   ds.histogram(x='D$LAB_TSC', type='split')
#'
#'   # Example 2: plot a combined histogram of the variable 'LAB_HDL'  default behaviour
#'   ds.histogram(x='D$LAB_HDL')
#'
#'   # Example 3: plot the histograms of LAB_HDL separately (one per study)
#'   ds.histogram(x='D$LAB_HDL', type='split')
#' 
#'   # clear the Datashield R sessions and logout
#'   datashield.logout(opals)
#'
#' }
#'
ds.histogram <- function(x=NULL, type='combine', datasources=NULL){
  
  # if no opal login details are provided look for 'opal' objects in the environment
  if(is.null(datasources)){
    datasources <- findLoginObjects()
  }
  
  if(is.null(x)){
    stop("Please provide the name of the input vector!", call.=FALSE)
  }
  
  # the input variable might be given as column table (i.e. D$x)
  # or just as a vector not attached to a table (i.e. x)
  # we have to make sure the function deals with each case
  xnames <- extract(x)
  varname <- xnames$elements
  obj2lookfor <- xnames$holders
  
  # check if the input object(s) is(are) defined in all the studies
  if(is.na(obj2lookfor)){
    defined <- isDefined(datasources, varname)
  }else{
    defined <- isDefined(datasources, obj2lookfor)
  }
  
  # call the internal function that checks the input object is of the same class in all studies.
  typ <- checkClass(datasources, x)
  
  # the input object must be a numeric or an integer vector
  if(typ != 'integer' & typ != 'numeric'){
    stop("The input object must be an integer or numeric vector.", call.=FALSE)
  }
  
  # get the range from each studyand produce the 'global' range
  cally1 <- paste0("rangeDS(", x,")")
  ranges <- unique(unlist(opal::datashield.aggregate(datasources, as.symbol(cally1))))
  range.arg <- c(min(ranges,na.rm=TRUE), max(ranges, na.rm=TRUE))
  if(range.arg[1] < 0){ r1 <- range.arg[1] * 1.1 }else{ r1 <- range.arg[1] * 0.9 }
  if(range.arg[2] < 0){ r2 <- range.arg[2] * 0.9 }else{ r2 <- range.arg[2] * 1.1 }

  # call the function that produces the histogram object to plot
  # get the seed
  seedval <- round(runif(1, 0, 1000))
  cally2 <- paste0('histogramDS(', x, ',', r1, ',', r2, ',', seedval, ')')
  hist.objs <- vector("list", length(datasources))
  invalidcells <- vector("list", length(datasources))
  outputs <- opal::datashield.aggregate(datasources, as.symbol(cally2))
  
  for(i in 1: length(datasources)){
    output <- outputs[[i]]
    if(is.null(output)){
      stop("Equidistant break points that span all the data points could not be find, in stdnames[i]!")
    }
    hist.objs[[i]] <- output$histobject
    invalidcells[[i]] <- output$invalidcells
  }
  
  # combine the histogram objects
  # 'breaks' and 'mids' are the same for all studies
  global.counts <- rep(0, length(hist.objs[[1]]$counts))
  global.density <- rep(0, length(hist.objs[[1]]$density))
  for(i in 1:length(datasources)){
    global.counts <- global.counts + hist.objs[[i]]$counts
    global.density <- global.density + hist.objs[[i]]$density
  }
  global.density <- global.density/3
  global.intensities <- global.density
  
  # generate the combined histogram object to plot
  combined.histobject <- hist.objs[[1]]
  combined.histobject$counts <- global.counts
  combined.histobject$density <- global.density
  combined.histobject$intensities <- combined.histobject$density
  
  # plot the individual histograms on the same graph
  # if the argument 'type'="combine" plot a combined histogram and if 'type'="split" plot single histograms separately
  if(type=="combine"){
    par(mfrow=c(1,1))
    plot(combined.histobject, xlab=varname, main='Histogram of the pooled data')
    return(combined.histobject)
  }else{  if(type=="split"){
    # set the graph area and plot
    ll <- length(datasources)
    if(ll > 1){
      if((ll %% 2) == 0){ numr <- ll/2 }else{ numr <- (ll+1)/2}
      numc <- 2
      par(mfrow=c(numr,numc))
      for(i in 1:ll){
        warning(names(datasources)[i], ": ", invalidcells[[i]], " invalid cells", immediate.=TRUE, call.=FALSE)
        plot(hist.objs[[i]], xlab=varname, main=paste("Histogram of ", names(datasources)[i], sep=""))
      }
      return(hist.objs)
    }else{
      par(mfrow=c(1,1))
      warning(names(datasources)[1], ": ", invalidcells[[1]], " invalid cells", immediate.=TRUE, call.=FALSE)
      plot(hist.objs[[1]], xlab=varname, main=paste("Histogram of ", names(datasources)[1], sep=""))
      return(hist.objs[[1]])
    }
  }else{
    stop('Function argument "type" has to be either "combine" or "split"')
  }
 }
}

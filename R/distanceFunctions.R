
########################
## DISTANCE FUNCTIONS ##
########################

# Contains a number of functions that can be used to compute distances, which in turn can be used to
# find outliers. Each of these functions has the same input and output format. Any additional arguments
# to functions should have default values.

# functions:

# Mahalanobis
# harmonicDist
# kernelDist
# kernelLogLike
# neighborDist
# DCMS
# stat_to_pvalue
# CSS

############# data_checks (not exported) #######################################

# Perform simple checks on input data frame to ensure that it can be used with distance functions.

data_checks <- function(dfv, column.nums, subset, S, M, check.na=TRUE, check.S=TRUE, check.M=FALSE) {

  #### perform simple checks on data
  # check that dfv is a matrix or data frame
  if (!is.matrix(dfv) & !is.data.frame(dfv))
    stop("dfv must be a matrix or data frame")

  # check that column.nums can be used to index dfv without error
  if (class(try(dfv[,column.nums],silent=TRUE))=='try-error')
    stop("column.nums must contain valid indexes for choosing columns in dfv")

  # extract variables from dfv
  df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])

  # check that all selected columns are numeric
  if (any(!(apply(df.vars,2,is.numeric))))
    stop("all selected columns of dfv must be numeric")

  # check that no NA values
  if (check.na & any(is.na(df.vars)))
    stop("dfv cannot contain NA values")

  # check that at least two rows in df.vars
  if (nrow(df.vars)<2)
  	stop("dfv must contain at least two rows")

  # check that subset can be used to index df.vars without error
  if ('try-error' %in% class(try(df.vars[subset,],silent=TRUE)))
    stop("subset must contain valid indexes for choosing rows in dfv")

  # subset rows in df.vars
  df.vars_subset <- as.matrix(df.vars[subset,,drop=FALSE])

  # check that at least two rows in df.vars_subset
  if (nrow(df.vars_subset)<2)
    stop("subset must index at least two rows in dfv")

  # calculate covariance of variables
  if (check.S) {

    # if S is NULL replace with covariance matrix
    if (is.null(S))
      S <- stats::cov(df.vars_subset, use="pairwise.complete.obs")

    # check that S is a matrix
    if (!is.matrix(S))
      stop("S must be a matrix")

    # check that S has the same number of rows and cols as variables in df.vars
    if (nrow(S)!=ncol(df.vars) | ncol(S)!=ncol(df.vars))
      stop("S must contain the same number of rows and columns as there are selected variables in dfv")

    # check that S contains no NA values
    if (any(is.na(S)))
      stop("covariance matrix S contains NA values")

    # check that inverse matrix of S can be calculated (not true if, for example, all values are the same)
    if ('try-error' %in% class(try(solve(S),silent=TRUE)))
      stop("covariance matrix S is exactly singular")

    # calculate inverse covariance matrix
    S_inv <- solve(S)
  } else {
  	S <- NULL
  	S_inv <- NULL
  }

  # calculate mean of variables
  if (check.M) {

    # if M is NULL replace with mean over variables
    if (is.null(M))
      M <- colMeans(df.vars_subset,na.rm=TRUE)

    # force M to be vector
    M <- as.vector(unlist(M))

    # check that M has one element per column of df.vars
    if (length(M)!=ncol(df.vars))
      stop("M must contain one value per selected column of dfv")
  } else {
  	M <- NULL
  }

  # return useful output
  output <- list(S=S, S_inv=S_inv, M=M)

}


############# Mahalanobis distance #############################################

#' Mahalanobis
#'
#' Calculates the Mahalanobis distance for each row (locus, SNP) in the data frame. Data are subset prior to calculating distances (see details).
#'
#' Under default options the standard Mahalanobis calculation is used, based on the mean and covariance matrix of the data. Addition arguments can be used to specify the mean and covariance matrix manually, or to define a subset of points that are used in the calculation. The input data frame can handle some missing data, as long as a covariance matrix can still be computed using the function cov(dfv[subset,column.nums],use="pairwise.complete.obs").
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate Mahalanobis distance (all other columns are ignored).
#' @param subset index the rows of the data frame that will be used to calculate the mean and covariance of the distribution (unless specified manually).
#' @param S the covariance matrix used to normalise the data in the Mahalanobis calculation. Leave as NULL to use the ordinary covariance matrix calculated using cov(dfv[subset,column.nums],use="pairwise.complete.obs").
#' @param M the point that Mahalanobis distance is measured from. Leave as NULL to measure distance from the mean of dfv[subset,column.nums].
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @examples
#' \dontrun{
#' #' # create a matrix of observations
#' df <- data.frame(x=rnorm(100),y=rnorm(100))
#'
#' # calculate Mahalanobis distances
#' distances <- Mahalanobis(df)
#'
#' # use this distance to look for outliers
#' Q95 <- quantile(distances, 0.95)
#' which(distances>Q95)
#' }
#' @importFrom stats cov
#' @export

########################################################################

Mahalanobis <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), S=NULL, M=NULL){

  #### perform simple checks on data
  dfv_check <- data_checks(dfv, column.nums, subset, S, M, check.na=FALSE, check.M=TRUE)

  # extract variables from dfv and dfv_check
  diff <- as.matrix(dfv[,column.nums,drop=FALSE])
  S_inv <- dfv_check$S_inv
  M <- dfv_check$M

  # calculate Mahalanobis distance
  for (i in 1:ncol(diff)) {
    diff[,i] <- diff[,i] - M[i]
  }
  distance <- Mod(sqrt(as.complex(rowSums((diff %*% S_inv) * diff, na.rm = TRUE))))

  return(distance)
} # end Mahalanobis


############# harmonic mean distance #############################################

#' Harmonic Mean Distance
#'
#' Calculates harmonic mean distance between points. Data are subset prior to calculating distances (see details).
#'
#' Takes a matrix or data frame as input, with observations in rows and statistics in columns. The parameter "column.nums" is used to select which columns to use in the analysis, all other columns are ignored.
#' The covariance is then calculated on a subset of this data, specified using the parameter "subset" (which defaults to all observations). All distances in the calculation are normalised by multiplying by the inverse of this covariance matrix. Alternatively, this matrix can be specified manually as an additional argument.
#' The harmonic mean distance of a point is calculated as the harmonic mean of the distance between this point and all points in the chosen subset.
#'
#' Note that this method cannot handle any NA values.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate harmonic mean distances (all other columns are ignored).
#' @param subset index the rows of the data frame that will be used to calculate the covariance matrix (unless specified manually).
#' @param S the covariance matrix used to normalise the data in the harmonic mean calculation. Leave as NULL to use the ordinary covariance matrix calculated using cov(dfv[subset,column.nums]).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @examples
#' \dontrun{
#' # create a data frame of observations
#' df <- data.frame(x=rnorm(100),y=rnorm(100))
#'
#' # calculate harmonic mean distances
#' distances <- harmonicDist(df)
#'
#' # use this distance to look for outliers
#' Q95 <- quantile(distances, 0.95)
#' which(distances>Q95)
#' }
#' @importFrom stats cov
#' @export

########################################################################

harmonicDist <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), S=NULL){

  #### perform simple checks on data
  dfv_check <- data_checks(dfv, column.nums, subset, S, M=NULL, check.na=TRUE, check.M=FALSE)

  # extract variables from dfv and dfv_check
  df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
  S_inv <- dfv_check$S_inv
  d <- ncol(df.vars)

  #### calculate harmonic mean distances using C++ function
  distances <- C_harmonicDist(split(t(df.vars),1:d), subset-1, split(S_inv,1:d))$distance

  return(distances)
} # end harmonicDist


############# nearest neighbor distance #############################################

#' Nearest Neighbor Distance
#'
#' Calculates nearest neighbor distance between points. Data are subset prior to calculating distances (see details).
#'
#' Takes a matrix or data frame as input, with observations in rows and statistics in columns. The parameter "column.nums" is used to select which columns to use in the analysis, all other columns are ignored.
#' The covariance is then calculated on a subset of this data, specified using the parameter "subset" (which defaults to all observations). All distances in the calculation are normalised by multiplying by the inverse of this covariance matrix. Alternatively, this matrix can be specified manually as an additional argument.
#' The nearest neighbor distance of a point is calculated as the closest distance between this point and all points in the chosen subset.
#'
#' Note that this method cannot handle NA values.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate nearest neighbor distances (all other columns are ignored).
#' @param subset index the rows of the data frame that will be used to calculate the covariance matrix (unless specified manually).
#' @param S the covariance matrix used to normalise the data in the nearest neighbor calculation. Leave as NULL to use the ordinary covariance matrix calculated using cov(dfv[subset,column.nums]).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @examples
#' \dontrun{
#' # create a data frame of observations
#' df <- data.frame(x=rnorm(100),y=rnorm(100))
#'
#' # calculate nearest neighbor distances
#' distances <- neighborDist(df)
#'
#' # use this distance to look for outliers
#' Q95 <- quantile(distances, 0.95)
#' which(distances>Q95)
#' }
#' @importFrom stats cov
#' @export

########################################################################

neighborDist <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), S=NULL){

  #### perform simple checks on data
  dfv_check <- data_checks(dfv, column.nums, subset, S, M=NULL, check.na=TRUE, check.M=FALSE)

  # extract variables from dfv and dfv_check
  df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
  S_inv <- dfv_check$S_inv
  d <- ncol(df.vars)

  #### calculate nearest neighbor distances using C++ function
  distances <- C_neighborDist(split(t(df.vars), 1:d), subset-1, split(S_inv,1:d))$distance

  return(distances)
} # end neighborDist


############# kernel density distance #############################################

#' Kernel Density Distance
#'
#' Calculates kernel density of all points from all others in multivariate space. Returns -2*log(density)
#' as a distance measure. Data are subset prior to calculating distances (see details).
#'
#' Takes a matrix or data frame as input, with observations in rows and statistics in columns. The parameter "column.nums" is used to select which columns to use in the analysis, all other columns are ignored.
#' The covariance is then calculated on a subset of this data, specified using the parameter "subset" (which defaults to all observations). The kernel bandwidth is multiplied by this covariance matrix. Alternatively, this matrix can be specified manually as an additional argument.
#' The kernel density deviance of a point is calculated as -2*log(density) of this point from all other points in the chosen subset.
#' Assumes a multivariate normal kernel with the same user-defined bandwidth in all dimensions (after normalization).
#'
#' Note that this method cannot handle NA values.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate kernel density distances (all other columns are ignored).
#' @param subset index the rows of the data frame that will be used to calculate the covariance matrix (unless specified manually).
#' @param bandwidth standard deviation of the normal kernel in each dimension. Can be a numerical value, or can be set to 'default', in which case Silverman's rule is used to select the bandwidth.
#' @param S the covariance matrix that the bandwidth is multiplied by. Leave as NULL to use the ordinary covariance matrix calculated using cov(dfv[subset,column.nums]).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @examples
#' \dontrun{
#' # create a data frame of observations
#' df <- data.frame(x=rnorm(100),y=rnorm(100))
#'
#' # calculate kernel density distances
#' distances <- kernelDist(df)
#'
#' # use this distance to look for outliers
#' Q95 <- quantile(distances, 0.95)
#' which(distances>Q95)
#' }
#' @importFrom stats cov
#' @export

########################################################################

kernelDist <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), bandwidth="default", S=NULL){

  #### perform simple checks on data
  dfv_check <- data_checks(dfv, column.nums, subset, S, M=NULL, check.na=TRUE, check.M=FALSE)

  # extract variables from dfv and dfv_check
  df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
  S_inv <- dfv_check$S_inv
  n <- nrow(df.vars)
  d <- ncol(df.vars)


  # check that bandwidth is either "default" or numeric. If default then apply Silverman's rule.
  if (is.numeric(bandwidth)) {
    if (bandwidth<=0 | !is.finite(bandwidth))
      stop("bandwidth must be greater than 0 and less than infinity")
  } else {
    if (is.na(bandwidth=="default")) {
      stop("bandwidth must be 'default' or numeric")
    } else {
      if (bandwidth=="default") {
        bandwidth = (4/(d+2))^(1/(d+4))*n^(-1/(d+4))
      } else {
        stop("bandwidth must be 'default' or numeric")
      }
    }
  }

  #### calculate kernel density distances using C++ function
  distances <- C_kernelDist(split(t(df.vars), 1:d), subset-1, bandwidth^2, split(S_inv,1:d))$distance

  return(distances)
} # end kernelDist


############# kernel density deviance #############################################

#' Kernel Density Deviance
#'
#' Calculates the Bayesian deviance (-2*log-likelihood) under the same kernel density model used
#' by kernelDist() for a range of bandwidths. Can be used to estimate the optimal
#' (maximum likelihood) bandwith to use in the kernelDist() function (see example). Data are subset prior to calculating distances (see details).
#'
#' Uses same input and model structure as kernelDist(). Calculates the log-likelihood using the
#' leave-one-out method, wherein the likelihood of point i is equal to its kernel density from every point j in the chosen subset, where j!=i. This avoids the issue of obtaining infinite likelihood at zero bandwidth, which would be the case under an ordinary kernel density model.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate kernel log-likelihood (all other columns are ignored).
#' @param subset index the rows of the data frame that will be used to calculate the covariance matrix (unless specified manually).
#' @param bandwidth a vector containing the range of bandwidths to be explored.
#' @param S the covariance matrix that the bandwidth is multiplied by. Leave as NULL to use the ordinary covariance matrix calculated using cov(dfv[subset,column.nums]).
#' @param reportProgress whether to report current progress of the algorithm to the console (TRUE/FALSE).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @examples
#' \dontrun{
#' # create a data frame of observations
#' df <- data.frame(x=rnorm(100),y=rnorm(100))
#'
#' # create a vector of bandwidths to explore
#' lambda <- seq(0.1,2,0.1)
#'
#' # obtain deviance at each of these bandwidths
#' deviance <- kernelDeviance(df,bandwidth=lambda,reportProgress=TRUE)
#'
#' # find the maximum-likelihood (minimum-deviance) bandwidth
#' lambda_ML <- lambda[which.min(deviance)]
#'
#' # use this value when calculating kernel density distances
#' distances <- kernelDist(df,bandwidth=lambda_ML)
#' }
#' @importFrom stats cov
#' @importFrom utils flush.console
#' @export

########################################################################

kernelDeviance <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), bandwidth=seq(0.1,1,0.1), S=NULL, reportProgress=FALSE){

  #### perform simple checks on data
  dfv_check <- data_checks(dfv, column.nums, subset, S, M=NULL, check.na=TRUE, check.M=FALSE)

  # extract variables from dfv and dfv_check
  df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
  S_inv <- dfv_check$S_inv
  d <- ncol(df.vars)

  # check that all elements of bandwidth are numeric and between 0 and infinity
  bandwidth <- as.vector(unlist(bandwidth))
  if (any(!is.numeric(bandwidth)))
    stop("bandwidth must be a numeric vector")
  if (any(bandwidth<=0) | any(!is.finite(bandwidth)))
    stop("bandwidth must contain values greater than 0 and less than infinity")

  #### calculate deviance for all bandwidths
  output <- rep(NA,length(bandwidth))
  for (i in 1:length(bandwidth)) {
    if (reportProgress) {
      message(paste("bandwidth ",i," of ",length(bandwidth),sep=""))
      utils::flush.console()
    }
    output[i] <- C_kernelDeviance(split(t(df.vars), 1:d), subset-1, bandwidth[i]^2, split(S_inv,1:d))$deviance
  }

  return(output)
} # end kernelDeviance


############# stat_to_pvalue #############################################

#' Convert statistics to p-values
#'
#' Convert raw statistics to p-values based on fractional ranks. Options are available for one- and two-tailed tests (see details).
#'
#' Selected columns in the input data frame are first converted to fractional ranks between 0 and 1 (inclusive). These values are then transformed based on whether a left-tailed, right-tailed or two-tailed p-value is desired (see details). Final values are then transformed again to occupy the range 0-1 exclusive (i.e. between 1/(n+1) and n/(n+1)). If the \code{subset} argument is used then ranks are calculated against the chosen subset only, which will lead to several observations having the same p-value.
#'
#' Each chosen column in the input data frame can be designated as left-tailed, right-tailed or two-tailed independently. The argument \code{two.tailed} is a boolean vector where TRUE indicates that the values should be converted to p-values based on a two-tailed test. The argument \code{right.tailed} is a boolean vector of the same length as \code{two.tailed}, where entries only apply if the corresponding entry of \code{two.tailed} is FALSE. For example, the input \code{two.tailed=c(TRUE,FALSE), right.tailed=c(FALSE,FALSE)} would produce a two-tailed p-value in the first variable and a left-tailed p-value in the second variable.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate p-values (all other columns are ignored).
#' @param subset index the rows of the data frame that are known contain values from the null distribution. Use all rows if no such information is available.
#' @param two.tailed a boolean vector with one entry for each chosen column, where TRUE indicates that the column should be converted to p-values based on a two-tailed test.
#' @param right.tailed a boolean vector with one entry for each chosen column, where TRUE indicates that the column should be converted to p-values based on a right-tailed test (see details).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @export

########################################################################

stat_to_pvalue <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), two.tailed=rep(TRUE,length(column.nums)), right.tailed=rep(FALSE,length(column.nums))){

	# perform simple checks on data
	dfv_check <- data_checks(dfv, column.nums, subset, S=NULL, M=NULL, check.na=TRUE, check.S=FALSE, check.M=FALSE)

	# extract variables from dfv and create df.p
	df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
	n <- nrow(df.vars)
	d <- ncol(df.vars)
	df.p <- as.data.frame(matrix(0,n,d))

	# check that two.tailed and right.tailed vectors are correct length
	if (length(two.tailed)!=d)
		stop('two.tailed must be a vector of same length as column.nums')
	if (length(right.tailed)!=d)
		stop('right.tailed must be a vector of same length as column.nums')

	# check whether using all values or a subset
	noSubset <- (length(subset)==nrow(dfv))

	# if using all values
	if (noSubset) {

		for (i in 1:d) {
			# convert ranking to value between 0 and 1 (inclusive)
			df.p[,i] <- (rank(df.vars[,i])-1)/(n-1)
			# convert to two-tailed if needed
			if (two.tailed[i]) {
				df.p[,i] <- 1-2*abs(df.p[,i]-0.5)
			} else {
				# get correct tail of distribution
				if (right.tailed[i])
					df.p[,i] <- 1-df.p[,i]
			}
			# ensure that final value is between 0 and 1 (exclusive)
			df.p[,i] <- (df.p[,i]*n+1)/(n+2)
		}

	}

	# if comparing against a null distribution
	if (!noSubset) {

		# get null points
		df.vars_subset <- as.matrix(df.vars[subset,,drop=FALSE])
		n2 <- nrow(df.vars_subset)

		for (i in 1:d) {
			# calculate p-value from position in ordered list, yielding a value between 0 and 1 (inclusive)
			df.p[,i] <- findInterval(df.vars[,i], sort(df.vars_subset[,i]))/n2
			# convert to two-tailed if needed
			if (two.tailed[i]) {
				df.p[,i] <- 1-2*abs(df.p[,i]-0.5)
			} else {
				# get correct tail of distribution
				if (right.tailed[i])
					df.p[,i] <- 1-df.p[,i]
			}
			# ensure that final value is between 0 and 1 (exclusive)
			df.p[,i] <- (df.p[,i]*n2+1)/(n2+2)
		}

	}

	return(df.p)
}


############# DCMS #############################################

#' De-correlated Composite of Multiple Signals (DCMS)
#'
#' Calculates the DCMS for each row (locus, SNP) in the data frame. Data are subset prior to calculating distances (see details).
#'
#' The selected columns of the \code{dfv} data frame (i.e. the columns specified by \code{column.nums}) should contain the raw test statistics, while the selected columns of the \code{dfp} data frame (i.e. the columns specified by \code{column.nums.p}) should contain the corresponding p-values. If the same data frame contains both raw statistics and p-values then this should be passed in as both \code{dfv} and \code{dfp}, with only the selected columns changing. The covariance matrix used in the DCMS calculation can be specified directly through the argument S, or if S=NULL then this matrix is calculated directly from selected rows and columns of \code{dfv}.
#'
#' @param dfv a data frame containing observations in rows and raw statistics in columns.
#' @param column.nums indexes the columns of \code{dfv} that contain raw statistics.
#' @param subset index the rows of the data frame that will be used to calculate the covariance matrix S (unless specified manually).
#' @param S the covariance matrix used to account for correlation between observations in the DCMS calculation. Leave as NULL to use the ordinary covariance matrix calculated using \code{cov(dfv[subset,column.nums],use="pairwise.complete.obs")}.
#' @param dfp a data frame containing observations in rows and p-values in columns.
#' @param column.nums.p indexes the columns of \code{dfp} that contain p-values.
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @importFrom stats cov
#' @export

########################################################################

DCMS <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), S=NULL, dfp, column.nums.p=1:ncol(dfp)) {

	# check that input dimensions work
	if (length(column.nums)!=length(column.nums.p))
		stop('column.nums must contain same number of values as column.nums.p')

	# perform simple checks on data
	dfv_check <- data_checks(dfv, column.nums, subset, S, M=NULL, check.na=TRUE, check.M=FALSE)
	dfp_check <- data_checks(dfp, column.nums.p, subset, S=NULL, M=NULL, check.na=TRUE, check.S=FALSE, check.M=FALSE)

	if (nrow(dfv)!=nrow(dfp))
		stop('dfv and dfp must contain the same number of entries')

	# extract variables from dfv
	df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
	n <- nrow(df.vars)
	d <- ncol(df.vars)
	df.p <- as.matrix(dfp[,column.nums.p,drop=FALSE])

	# calculate correlation matrix from covariance matrix
	S <- dfv_check$S
	corrMat <- S/sqrt(outer(diag(S),diag(S)))

	# calculate DCMS
	DCMS <- 0
	for (i in 1:d) {
		DCMS <- DCMS + (log(1-df.p[,i])-log(df.p[,i]))/sum(abs(corrMat[i,]))
	}

	return(DCMS)
}


############# CSS #############################################

#' Composite Selection Signal
#'
#' Calculates the CSS statistic for each row (locus, SNP) in the data frame. Data are subset prior to calculating distances (see details).
#'
#' CSS is calculated based on the method described in Randhawa et al (2014). Selected columns of \code{dfv} are first converted to fractional ranks (see \code{?stat_to_pvalue}). Fractional ranks are then converted to z-scores using the inverse cumulative normal transformation. The mean z-score is then taken over variables, and converted to a p-value based on the appropriate normal distribution. Finally, the CSS statistic is defined as -log(p-value) in base 10.
#'
#' As fractional ranks are obtained using the \code{stat_to_pvalue} function, the various arguments to this function are available. This includes options for calculating fractional ranks based on one- and two-tailed methods for each variable independently.
#'
#' @param dfv a data frame containing observations in rows and statistics in columns.
#' @param column.nums indexes the columns of the data frame that will be used to
#' calculate CSS (all other columns are ignored).
#' @param subset index the rows of the data frame that fractional ranks will be relative to.
#' @param two.tailed a boolean vector with one entry for each chosen column, where TRUE indicates that the column should be converted to fractinal ranks based on a two-tailed test.
#' @param right.tailed a boolean vector with one entry for each chosen column, where TRUE indicates that the column should be converted to fractional ranks based on a right-tailed test (see \code{?stat_to_pvalue}).
#'
#' @author Robert Verity \email{r.verity@imperial.ac.uk}
#' @references Randhawa, Imtiaz Ahmed Sajid, et al. "Composite selection signals can localize the trait specific genomic regions in multi-breed populations of cattle and sheep." BMC genetics 15.1 (2014): 1.
#' @export

########################################################################

CSS <- function(dfv, column.nums=1:ncol(dfv), subset=1:nrow(dfv), two.tailed=rep(TRUE,length(column.nums)), right.tailed=rep(FALSE,length(column.nums))){

	# perform simple checks on data
	dfv_check <- data_checks(dfv, column.nums, subset=subset, S, M=NULL, check.na=TRUE, check.S=FALSE, check.M=FALSE)

	# extract variables from dfv
	df.vars <- as.matrix(dfv[,column.nums,drop=FALSE])
	n <- nrow(df.vars)
	d <- ncol(df.vars)

	# convert variables to rank fraction
	df.rank <- stat_to_pvalue(dfv, column.nums, subset, two.tailed, right.tailed)

	# calculate z-score from rank fraction
	z <- 0
	for (i in 1:d) {
		z <- z + qnorm(df.rank[,i])
	}
	z <- z/d

	# calculate p-value and CSS
	p <- pnorm(z, sd=1/sqrt(d))
	CSS <- -log(p)/log(10)

	return(CSS)
}

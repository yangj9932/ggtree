% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/inset.R
\name{inset}
\alias{inset}
\title{inset}
\usage{
inset(tree_view, insets, width, height, hjust = 0, vjust = 0, x = "node",
  reverse_x = FALSE, reverse_y = FALSE)
}
\arguments{
\item{tree_view}{tree view}

\item{insets}{a list of ggplot objects, named by node number}

\item{width}{width of inset}

\item{height}{height of inset}

\item{hjust}{horizontal adjustment}

\item{vjust}{vertical adjustment}

\item{x}{x position, one of 'node' and 'branch'}

\item{reverse_x}{whether x axis was reversed by scale_x_reverse}

\item{reverse_y}{whether y axis was reversed by scale_y_reverse}
}
\value{
tree view with insets
}
\description{
add insets in a tree
}
\author{
Guangchuang Yu
}

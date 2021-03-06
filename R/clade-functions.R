##' get taxa name of a selected node (or tree if node=NULL) sorted by their position in plotting
##'
##'
##' @title get_taxa_name
##' @param tree_view tree view
##' @param node node
##' @return taxa name vector
##' @export
##' @author Guangchuang Yu
get_taxa_name <- function(tree_view=NULL, node=NULL) {
    tree_view %<>% get_tree_view

    df <- tree_view$data
    if (!is.null(node)) {
        sp <- get.offspring.df(df, node)
        df <- df[sp, ]
    }

    with(df, {
        i = order(y, decreasing=T)
        label[i][isTip[i]]
    })
}


##' view a clade of tree
##'
##'
##' @title viewClade
##' @param tree_view full tree view
##' @param node internal node number
##' @param xmax_adjust adjust xmax
##' @return clade plot
##' @importFrom ggplot2 ggplot_build
##' @importFrom ggplot2 coord_cartesian
##' @export
##' @author Guangchuang Yu
viewClade <- function(tree_view=NULL, node, xmax_adjust=0) {
    tree_view %<>% get_tree_view
    ## xd <- tree_view$data$branch.length[node]/2

    cpos <- get_clade_position(tree_view, node=node)
    xmax <- ggplot_build(tree_view)$layout$panel_ranges[[1]]$x.range[2]

    attr(tree_view, 'viewClade') <- TRUE
    attr(tree_view, 'viewClade_node') <- node

    ## tree_view+xlim(cpos$xmin, xmax + xmax_adjust) + ylim(cpos$ymin, cpos$ymax)
    tree_view + coord_cartesian(xlim=c(cpos$xmin, xmax), ylim=c(cpos$ymin, cpos$ymax), expand=FALSE)
}

is.viewClade <- function(tree_view) {
    x <- attr(tree_view, 'viewClade')
    !is.null(x) && x
}



##' collapse a clade
##'
##'
##' @title collapse-ggtree
##' @rdname collapse
##' @param x tree view
##' @param node clade node
##' @param ... additional parameters
##' @return tree view
##' @method collapse ggtree
##' @export
##' @seealso expand
##' @author Guangchuang Yu
collapse.ggtree <- function(x=NULL, node, ...) {
    tree_view <- get_tree_view(x)

    df <- tree_view$data

    if (is.na(df$x[df$node == node])) {
        warning("specific node was already collapsed...")
        return(tree_view)
    }

    sp <- get.offspring.df(df, node)
    sp.df <- df[sp,]
    ## df[node, "isTip"] <- TRUE
    sp_y <- range(sp.df$y, na.rm=TRUE)
    ii <- which(df$y > max(sp_y))
    if (length(ii)) {
        df$y[ii] <- df$y[ii] - diff(sp_y)
    }
    df$y[node] <- min(sp_y)

    df[sp, "x"] <- NA
    df[sp, "y"] <- NA

    df <- reassign_y_from_node_to_root(df, node)

    ## re-calculate branch mid position
    df <- calculate_branch_mid(df)

    ii <- which(!is.na(df$x))
    df$angle[ii] <- calculate_angle(df[ii,])$angle

    tree_view$data <- df
    clade <- paste0("clade_", node)
    attr(tree_view, clade) <- sp.df
    tree_view
}

##' expand collased clade
##'
##'
##' @title expand
##' @param tree_view tree view
##' @param node clade node
##' @return tree view
##' @export
##' @seealso collapse
##' @author Guangchuang Yu
expand <- function(tree_view=NULL, node) {
    tree_view %<>% get_tree_view

    clade <- paste0("clade_", node)
    sp.df <- attr(tree_view, clade)
    if (is.null(sp.df)) {
        return(tree_view)
    }
    df <- tree_view$data
    ## df[node, "isTip"] <- FALSE
    sp_y <- range(sp.df$y)
    ii <- which(df$y > df$y[node])
    df[ii, "y"] <- df[ii, "y"] + diff(sp_y)

    sp.df$y <- sp.df$y - min(sp.df$y) + df$y[node]
    df[sp.df$node,] <- sp.df

    root <- which(df$node == df$parent)
    pp <- node
    while(any(pp != root)) {
        df[pp, "y"] <- mean(df$y[getChild.df(df, pp)])
        pp <- df$parent[pp]
    }
    j <- getChild.df(df, pp)
    j <- j[j!=pp]
    df[pp, "y"] <- mean(df$y[j])

    ## re-calculate branch mid position
    df <- calculate_branch_mid(df)

    tree_view$data <- calculate_angle(df)
    attr(tree_view, clade) <- NULL
    tree_view
}

##' rotate 180 degree of a selected branch
##'
##'
##' @title rotate
##' @param tree_view tree view
##' @param node selected node
##' @return ggplot2 object
##' @export
##' @author Guangchuang Yu
rotate <- function(tree_view=NULL, node) {
    tree_view %<>% get_tree_view

    df <- tree_view$data
    sp <- get.offspring.df(df, node)
    sp_idx <- with(df, match(sp, node))
    tip <- sp[df$isTip[sp_idx]]
    sp.df <- df[sp_idx,]
    ii <- with(sp.df, match(tip, node))
    jj <- ii[order(sp.df$y[ii])]
    sp.df[jj,"y"] <- rev(sp.df$y[jj])
    sp.df[-jj, "y"] <- NA
    sp.df <- re_assign_ycoord_df(sp.df, tip)

    df[sp_idx, "y"] <- sp.df$y
    ## df$node == node is TRUE when node was root
    df[df$node == node, "y"] <- mean(df$y[df$parent == node & df$node != node])
    pnode <- df$parent[df$node == node]
    if (pnode != node && !is.na(pnode)) {
        df[df$node == pnode, "y"] <- mean(df$y[df$parent == pnode])
    }

    tree_view$data <- calculate_angle(df)
    tree_view
}



##' flip position of two selected branches
##'
##'
##' @title flip
##' @param tree_view tree view
##' @param node1 node number of branch 1
##' @param node2 node number of branch 2
##' @return ggplot2 object
##' @export
##' @author Guangchuang Yu
flip <- function(tree_view=NULL, node1, node2) {
    tree_view %<>% get_tree_view

    df <- tree_view$data
    p1 <- with(df, parent[node == node1])
    p2 <- with(df, parent[node == node2])

    if (p1 != p2) {
        stop("node1 and node2 should share a same parent node...")
    }

    sp1 <- c(node1, get.offspring.df(df, node1))
    sp2 <- c(node2, get.offspring.df(df, node2))

    sp1.df <- df[sp1,]
    sp2.df <- df[sp2,]

    min_y1 <- min(sp1.df$y, na.rm=TRUE)
    min_y2 <- min(sp2.df$y, na.rm=TRUE)

    if (min_y1 < min_y2) {
        tmp <- sp1.df
        sp1.df <- sp2.df
        sp2.df <- tmp
        tmp <- sp1
        sp1 <- sp2
        sp2 <- tmp
    }

    min_y1 <- min(sp1.df$y, na.rm=TRUE)
    min_y2 <- min(sp2.df$y, na.rm=TRUE)

    space <- min(sp1.df$y, na.rm=TRUE) - max(sp2.df$y, na.rm=TRUE)
    sp1.df$y <- sp1.df$y - abs(min_y1 - min_y2)
    sp2.df$y <- sp2.df$y + max(sp1.df$y, na.rm=TRUE) + space - min(sp2.df$y, na.rm=TRUE)


    df[sp1, "y"] <- sp1.df$y
    df[sp2, "y"] <- sp2.df$y

    ## yy <- df$y[-c(sp1, sp2)]
    ## df$y[-c(sp1, sp2)] <- yy + ((min(sp2.df$y, na.rm=TRUE) - max(yy)) - (min(yy) - max(sp1.df$y, na.rm=TRUE)))/2

    anc <- getAncestor.df(df, node1)
    ii <- match(anc, df$node)
    df[ii, "y"] <- NA
    currentNode <- unlist(as.vector(sapply(anc, getChild.df, df=df)))
    currentNode <- currentNode[!currentNode %in% anc]

    tree_view$data <- re_assign_ycoord_df(df, currentNode)
    tree_view$data <- calculate_angle(tree_view$data)
    tree_view
}


##' scale clade
##'
##'
##' @title scaleClade
##' @param tree_view tree view
##' @param node clade node
##' @param scale scale
##' @param vertical_only logical. If TRUE, only vertical will be scaled.
##' If FALSE, the clade will be scaled vertical and horizontally.
##' TRUE by default.
##' @return tree view
##' @export
##' @author Guangchuang Yu
scaleClade <- function(tree_view=NULL, node, scale=1, vertical_only=TRUE) {
    tree_view %<>% get_tree_view

    if (scale == 1) {
        return(tree_view)
    }

    df <- tree_view$data
    sp <- get.offspring.df(df, node)
    sp.df <- df[sp,]

    ## sp_nr <- nrow(sp.df)
    ## span <- diff(range(sp.df$y))/sp_nr

    ## new_span <- span * scale
    old.sp.df <- sp.df
    sp.df$y <- df$y[node] + (sp.df$y - df$y[node]) * scale
    if (! vertical_only) {
        sp.df$x <- df$x[node] + (sp.df$x - df$x[node]) * scale
    }

    scale_diff.up <- max(sp.df$y) - max(old.sp.df$y)
    scale_diff.lw <- min(sp.df$y) - min(old.sp.df$y)

    ii <- df$y > max(old.sp.df$y)
    if (sum(ii) > 0) {
        df[ii, "y"] <- df$y[ii] + scale_diff.up
    }

    jj <- df$y < min(old.sp.df$y)
    if (sum(jj) > 0) {
        df[jj, "y"] <- df$y[jj] + scale_diff.lw
    }

    df[sp,] <- sp.df

    if (! "scale" %in% colnames(df)) {
        df$scale <- 1
    }
    df[sp, "scale"] <- df[sp, "scale"] * scale

    df <- reassign_y_from_node_to_root(df, node)

    ## re-calculate branch mid position
    df <- calculate_branch_mid(df)

    tree_view$data <- calculate_angle(df)


    if (is.viewClade(tree_view)) {
        vc_node <- attr(tree_view, 'viewClade_node')
        tree_view <- viewClade(tree_view, vc_node)
    }

    tree_view
}



reassign_y_from_node_to_root <- function(df, node) {
    root <- which(df$node == df$parent)
    pp <- df$parent[node]
    while(any(pp != root)) {
        df[pp, "y"] <- mean(df$y[getChild.df(df, pp)])
        pp <- df$parent[pp]
    }
    j <- getChild.df(df, pp)
    j <- j[j!=pp]
    df[pp, "y"] <- mean(df$y[j])
    return(df)
}

#
class TreeAppModule_TreeView extends TreeAppModule
    constructor: ->
        super()
        
        @name = 'Tree View'
        
        @actions.push
            txt: "Delete current tree item"
            key: [ "Del" ]
            fun: ( evt, app ) =>
                if app.selected_view == "TreeView"
                    for path in app.data.selected_tree_items
                        #prevent deleting root item (session)
                        if path.length > 1
                            m = path[ path.length - 1 ]
                            path[ path.length - 2 ].rem_child m
                            
                            @delete_from_tree app, m
                    
        @actions.push
            txt: ""
            key: [ "UpArrow" ]
            fun: ( evt, app ) =>
                items = app.data.get_selected_tree_items()
                session = app.data.selected_session()
                if items.length == 0
                    app.data.selected_tree_items.clear()
                    app.data.selected_tree_items.push [ session ]
                else if items.length == 1
                    #first search position of current selected item
                    it = items[ 0 ]
                    tv = app.layouts[session.model_id]._pan_vs_id.TreeView.treeview.flat
                    flat = []
                    for tree in tv
                        flat.push tree.item
                    index = flat.indexOf it
                    
                    if index > 0
                        #then add previous item to selected
                        new_item_selected = flat[index - 1]
                        path = app.data.get_root_path new_item_selected
                        app.data.selected_tree_items.clear()
                        for item in path
                            app.data.selected_tree_items.push item
                    

        @actions.push
            txt: ""
            key: [ "DownArrow" ]
            fun: ( evt, app ) =>
                #
                items = app.data.get_selected_tree_items()
                session = app.data.selected_session()
                if items.length == 0
                    app.data.selected_tree_items.clear()
                    app.data.selected_tree_items.push [ session ]
                    
                else if items.length == 1
                    #first search position of current selected item
                    it = items[ 0 ]
                    tv = app.layouts[session.model_id]._pan_vs_id.TreeView.treeview.flat
                    flat = []
                    for tree in tv
                        flat.push tree.item
                    index = flat.indexOf it
                    
                    if index < flat.length-1
                        #then add next item to selected
                        new_item_selected = flat[index + 1]
                        path = app.data.get_root_path new_item_selected
                        app.data.selected_tree_items.clear()
                        for item in path
                            app.data.selected_tree_items.push item

        @actions.push
            txt: ""
            key: [ "LeftArrow" ]
            fun: ( evt, app ) =>
                # Close selected items
                items = app.data.selected_tree_items
                for item in items
                    close = @is_close app, item
                    if item[ item.length - 1 ]._children.length > 0 and close == false
                        @add_item_to_close_tree app, item
                            
        @actions.push
            txt: ""
            key: [ "RightArrow" ]
            fun: ( evt, app ) =>
                # Open selected items
                items = app.data.selected_tree_items
                for item in items
                    close = @is_close app, item
                    if item[ item.length - 1 ]._children.length > 0 and close == true
                        @rem_item_to_close_tree app, item
                    
        @actions.push
            txt: ""
            key: [ "Enter" ]
            fun: ( evt, app ) =>
                if app.selected_view == "TreeView"
                    # Show/hide items
                    path_items = app.data.selected_tree_items
                    for path_item in path_items
                        item = path_item[ path_item.length - 1]
                        for p in app.data.panel_id_list()
                            app.data.visible_tree_items[ p ].toggle item
                        
    delete_from_tree: ( app,  item ) =>
        #delete children
        for c in item._children
            if c._children.length > 0
                @delete_from_tree app, c
            app.data.closed_tree_items.remove c
            for p in app.data.panel_id_list()
                app.data.visible_tree_items[ p ].remove c
        
        #delete item
        app.data.closed_tree_items.remove item
        for p in app.data.panel_id_list()
            app.data.visible_tree_items[ p ].remove item
        app.data.selected_tree_items.clear()
        
        # TODO
#         if item instanceof ImgItem
        # if item is using animation module, display settings anim_time._max should loose 1 or do something according to time
    
    is_close: ( app, item ) ->
        for closed_item_path in app.data.closed_tree_items
            if item.equals closed_item_path
                return true
        return false
    
    add_item_to_close_tree: ( app, item ) ->
        app.data.closed_tree_items.push item
        
    rem_item_to_close_tree: ( app, item ) ->
        ind = app.data.closed_tree_items.indexOf item
        app.data.closed_tree_items.splice ind, 1
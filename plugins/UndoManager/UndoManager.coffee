# each time you are going to make an important modification, call snapshot()
# 
class UndoManager
    #
    constructor: ( @model ) ->
        @max_patchs = 20
        @patch_undo = []
        @patch_redo = []
    
    #
    snapshot: ->
        date = @_date_last_snapshot()
        
        # if something has changed since previous undo or snapshot
        if @model._date_last_modification > date
            @patch_redo = []
            
            @patch_undo.push
                date: Model._counter
                data: @model.get_state date

            # console.log @model.get_state date
                
    #
    undo: ( num = 1 ) ->
        # we make a snapshot for eventual redos
        @snapshot()

        num = Math.min num, @patch_undo.length - 1
        if num > 0
            # last states go to redo
            for n in [ 0 ... num ]
                @patch_redo.push @patch_undo.pop()
                
            # modify state
            @_set_state_undo_list()
        
    #
    redo: ( num = 1 ) ->
        date = @_date_last_snapshot()
        if @model._date_last_modification > date
            @patch_redo = []
            
        num = Math.min num, @patch_redo.length
        if num > 0
            # last states go to redo
            for n in [ 0 ... num ]
                @patch_undo.push @patch_redo.pop()
        
            # modify state
            @_set_state_undo_list()

    # set model state according to all patches from @patch_undo
    _set_state_undo_list: ->
        # compute the state using patches from the beginning to the wanted date
        map = {}
        for p in @patch_undo
            lst = p.data.split "\n"
            lst.shift() # model_id
            for l in lst when l.length
                s = l.split " "
                map[ s[ 0 ] ] = 
                    type: s[ 1 ]
                    data: s[ 2 ]
                    buff: undefined
                    # unch: true

        #         r = "r= "
        #         for k, i of map
        #             r += "\n" + k + " " + i.type + " " + i.data
        #         console.log r

        # change the model
        @model._set_state map[ @model.model_id ].data, map

        # 
        if @patch_undo.length
            @patch_undo[ @patch_undo.length - 1 ].date = Model._counter + 2

    _date_last_snapshot: ->
        if @patch_undo.length
            return @patch_undo[ @patch_undo.length - 1 ].date
        return -1

        

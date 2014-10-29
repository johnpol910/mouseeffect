'use strict'

angular.module('PubNubAngularApp')
  .controller 'JoinCtrl', ($rootScope, $scope, $location, PubNub) ->
    $scope.data = {username:'User ' + Math.floor(Math.random() * 1000)}
    $scope.watch_flag = false;
    $scope.joinmornitor = ->
      $rootScope.watch_flag = true
      $scope.join()
    $scope.join = ->
      $rootScope.data ||= {}
      $rootScope.data.username = $scope.data?.username
      $rootScope.data.super    = $scope.data?.super
      $rootScope.data.uuid     = Math.floor(Math.random() * 1000000) + '__' + $scope.data.username

      $rootScope.secretKey = if $scope.data.super then 'sec-c-MmIzMDAzNDMtODgxZC00YzM3LTk1NTQtMzc4NWQ1NmZhYjIy' else null
      $rootScope.authKey   = if $scope.data.super then 'ChooseABetterSecret' else null

      PubNub.init({
        subscribe_key : 'sub-c-d66562f0-62b0-11e3-b12d-02ee2ddab7fe'
        publish_key   : 'pub-c-e2b65946-31f0-4941-a1b8-45bab0032dd8'
        # WARNING: DEMO purposes only, never provide secret key in a real web application!
        secret_key    : $rootScope.secretKey
        auth_key      : $rootScope.authKey
        uuid          : $rootScope.data.uuid
        ssl           : true
      })
      
      if $scope.data.super
        ### Grant access to the SuperHeroes room for supers only! ###
        PubNub.ngGrant({channel:'SuperHeroes',auth_key:$rootScope.authKey,read:true,write:true,callback:->console.log('SuperHeroes! all set', arguments)})
        PubNub.ngGrant({channel:"SuperHeroes-pnpres",auth_key:$rootScope.authKey,read:true,write:false,callback:->console.log('SuperHeroes! presence all set', arguments)})
        # Let everyone see the control channel so they can retrieve the rooms list
        PubNub.ngGrant({channel:'__controlchannel',read:true,write:true,callback:->console.log('control channel all set', arguments)})
        PubNub.ngGrant({channel:'__controlchannel-pnpres',read:true,write:false,callback:->console.log('control channel presence all set', arguments)})

      $location.path '/action'
      
    $(".prettyprint")

angular.module('PubNubAngularApp')
  .controller 'GameCtrl', ($rootScope, $scope, $location, $timeout, PubNub) ->
    $location.path '/join' unless PubNub.initialized()
    
    ### Use a "control channel" to collect channel creation messages ###
    $scope.controlChannel = '__controlchannel'
    $scope.channels = []
    $scope.objects = []
    $scope.game_area = $(".game-area")

    $scope.prev_obj = new Object()
    $scope.me_obj = new Object()
    $scope.me_obj.x = Math.floor(Math.random() * $($scope.game_area).width() - 100 ) + 50
    $scope.me_obj.y = Math.floor(Math.random() * $($scope.game_area).height() - 100 ) + 50
    $scope.me_obj.stepx = 1;
    $scope.me_obj.stepy = 1;
    $scope.me_obj.angle = Math.floor(Math.random() * 360 )
    $scope.me_obj.angle_str = 'rotate(' + $scope.me_obj.angle + 'deg)'
    $scope.me_obj.color = "rgb(" + Math.floor(Math.random() * 255) + "," + Math.floor(Math.random() * 255) + "," + Math.floor(Math.random() * 255) + ")"
    $scope.moveable = true
    $scope.mouse_pos_x = $scope.me_obj.x
    $scope.mouse_pos_y = $scope.me_obj.y

    $scope.bombs = []

    $scope.shoot_bomb = (ev) ->
      posx = ev.layerX
      posy = ev.layerY
      bomb_obj = new Object()
      bomb_obj = $scope.get_angle_and_step $scope.me_obj.x, ($scope.me_obj.y - 45 ), posx, (posy - 45)
      tmp_pos = $scope.update_pos bomb_obj.angle, $scope.me_obj.x, $scope.me_obj.y, bomb_obj.stepx, bomb_obj.stepy, 50 
      bomb_obj.x = tmp_pos.x      
      bomb_obj.y = tmp_pos.y
      bomb_obj.angle_str = 'rotate(' + bomb_obj.angle + 'deg)'
      $scope.bombs.push bomb_obj
      return

    $scope.update_pos = (angle, posx, posy, stepx, stepy, size ) ->
      ret = new Object()
      tmpstepx = Math.abs(Math.sin((angle % 180 ) / 180 * 3.14 ))
      tmpstepy = Math.abs(Math.cos((angle % 180 ) / 180 * 3.14 ))      
      ret.x = posx + stepx * tmpstepx * size
      ret.y = posy + stepy * tmpstepy * size
      return ret

    $scope.move_bombobject = ->
      i = 0
      while i < $scope.bombs.length
        tmp_pos = $scope.update_pos $scope.bombs[i].angle, $scope.bombs[i].x, $scope.bombs[i].y, $scope.bombs[i].stepx, $scope.bombs[i].stepy, 20         
        $scope.bombs[i].x = tmp_pos.x
        $scope.bombs[i].y = tmp_pos.y
        if $scope.bombs[i].x < 0 || $scope.bombs[i].y < 0 || $scope.bombs[i].x > $($scope.game_area).width() || $scope.bombs[i].y > $($scope.game_area).height()
          $scope.bombs.splice i, 1
        i++
      return;

    $scope.mousemove_object = (ev) ->
      posx = ev.layerX
      posy = ev.layerY
      $scope.mouse_pos_x = posx - 20
      $scope.mouse_pos_y = posy - 20
      tmp_obj = new Object()
      tmp_obj = $scope.get_angle_and_step $scope.me_obj.x, $scope.me_obj.y, $scope.mouse_pos_x, $scope.mouse_pos_y
      $scope.me_obj.angle = tmp_obj.angle
      $scope.me_obj.stepx = tmp_obj.stepx
      $scope.me_obj.stepy = tmp_obj.stepy
      return

    $scope.publish_obj = () ->
      return unless $scope.selectedChannel
      ###console.log $scope.me_obj.x, $scope.me_obj.y, $scope.me_obj.color, $scope.me_obj.angle_str###
      PubNub.ngPublish { channel: $scope.selectedChannel, message: {"type":"object", "x": $scope.me_obj.x, "y": $scope.me_obj.y, "angle_str":$scope.me_obj.angle_str, "color": $scope.me_obj.color, "user": $rootScope.data.username  } }
      return

    $scope.move_object = ->
      angle = $scope.me_obj.angle
      $scope.me_obj.angle_str = 'rotate(' + $scope.me_obj.angle + 'deg)'
      tmp_pos = $scope.update_pos $scope.me_obj.angle, $scope.me_obj.x, $scope.me_obj.y, $scope.me_obj.stepx, $scope.me_obj.stepy, 15
      $scope.me_obj.x = tmp_pos.x
      $scope.me_obj.y = tmp_pos.y

      if Math.abs($scope.me_obj.x - $scope.mouse_pos_x ) < 15 && Math.abs($scope.me_obj.y - $scope.mouse_pos_y ) < 15
        $scope.me_obj.x = $scope.mouse_pos_x 
        $scope.me_obj.y = $scope.mouse_pos_y 
      
      if $scope.me_obj.x > ($($scope.game_area).width() - 50)
        $scope.me_obj.x = $($scope.game_area).width() - 50
      if $scope.me_obj.x < 50
        $scope.me_obj.x = 50
      
      if $scope.me_obj.y > ($($scope.game_area).height() - 50)
        $scope.me_obj.y = $($scope.game_area).height() - 50

      if $scope.me_obj.y < 50
        $scope.me_obj.y = 50

      if $scope.prev_obj.x == $scope.me_obj.x && $scope.prev_obj.y == $scope.me_obj.y && $scope.prev_obj.angle == $scope.me_obj.angle 
        a = a + 1 
      else
        $scope.publish_obj()        
      tmp_obj = new Object()
      tmp_obj.x = $scope.me_obj.x
      tmp_obj.y = $scope.me_obj.y
      tmp_obj.angle = $scope.me_obj.angle
      $scope.prev_obj = tmp_obj

      return

    $scope.start_timer_for_obj = () ->
      $scope.move_object()
      $scope.move_bombobject()
      $timeout ->
         $scope.start_timer_for_obj()
      , 10

    $scope.start_timer_for_obj()

    $scope.get_angle_and_step = (cx, cy, p1x, p1y ) ->
      ret = new Object()
      p0x = cx
      p0y = cy - 10
      p0c = Math.sqrt(Math.pow(cx-p0x,2)+
                        Math.pow(cy-p0y,2))
      p1c = Math.sqrt(Math.pow(cx-p1x,2)+
                        Math.pow(cy-p1y,2))
      p0p1 = Math.sqrt(Math.pow(p1x-p0x,2)+
                         Math.pow(p1y-p0y,2))
      angle = Math.acos((p1c*p1c+p0c*p0c-p0p1*p0p1)/(2*p1c*p0c)) / 3.14 * 180
      if p1x < cx 
        angle = 360 - angle
        ret.stepx = -1
      else 
        ret.stepx = 1
      if p1y < cy
        ret.stepy = -1
      else
        ret.stepy = 1
      ret.angle = angle
      ret

    ### Publish a chat message ###
    $scope.publish = ->
      return unless $scope.selectedChannel
      PubNub.ngPublish { channel: $scope.selectedChannel, message: {text:$scope.newMessage, user:$scope.data.username} }
      $scope.newMessage = ''

    ### Create a new channel ###
    $scope.createChannel = ->
      console.log 'createChannel', $scope
      return unless $scope.data.super && $scope.newChannel
      channel = $scope.newChannel
      $scope.newChannel = ''

      # grant anonymous access to channel and presence
      PubNub.ngGrant({channel:channel,read:true,write:true,callback:->console.log("#{channel} all set", arguments)})
      PubNub.ngGrant({channel:"#{channel}-pnpres",read:true,write:false,callback:->console.log("#{channel} presence all set", arguments)})

      # publish the channel creation message to the control channel
      PubNub.ngPublish { channel: $scope.controlChannel, message: channel }

      # wait a tiny bit before selecting the channel to allow time for the presence
      # handlers to register
      setTimeout ->
        $scope.subscribe channel
        $scope.showCreate = false
      , 1000

    ### Select a channel to display chat history & presence ###
    $scope.subscribe = (channel) ->

      return if channel == $scope.selectedChannel
      PubNub.ngUnsubscribe { channel: $scope.selectedChannel } if $scope.selectedChannel
      $scope.selectedChannel = channel
      $scope.messages = ['Welcome to ' + channel]

      PubNub.ngSubscribe {
        channel: $scope.selectedChannel
        auth_key: $scope.authKey
        state: {"city":$rootScope.data?.city || 'unknown'}
        error: -> console.log arguments
      }
      $rootScope.$on PubNub.ngPrsEv($scope.selectedChannel), (ngEvent, payload) ->
        $scope.$apply ->
          userData = PubNub.ngPresenceData $scope.selectedChannel
          newData  = {}
          $scope.users    = PubNub.map PubNub.ngListPresence($scope.selectedChannel), (x) ->
            newX = x
            if x.replace
              newX = x.replace(/\w+__/, "")
            if x.uuid
              newX = x.uuid.replace(/\w+__/, "")
            newData[newX] = userData[x] || {}
            newX
          $scope.userData = newData

      PubNub.ngHereNow { channel:$scope.selectedChannel }

      $rootScope.$on PubNub.ngMsgEv($scope.selectedChannel), (ngEvent, payload) ->
        is_exists = $scope.is_exists_user payload.message.user
        if is_exists == false
          return
        tmp_obj = new Object()
        tmp_obj.user = payload.message.user
        tmp_obj.x = payload.message.x
        tmp_obj.y = payload.message.y
        tmp_obj.color = payload.message.color
        tmp_obj.angle_str = payload.message.angle_str

        $scope.$apply -> 
          if payload.message.type == "object"
            i = 0
            tmp_flag = false
            while i < $scope.objects.length
              if payload.message.user == $scope.objects[i].user
                $scope.objects[i].x = tmp_obj.x
                $scope.objects[i].y = tmp_obj.y
                $scope.objects[i].color = tmp_obj.color
                $scope.objects[i].angle_str = tmp_obj.angle_str
                tmp_flag = true
                break
              i++
            if tmp_flag == false
              $scope.objects.push tmp_obj

            
          return;
      PubNub.ngHistory { channel: $scope.selectedChannel, auth_key: $scope.authKey, count:500 }


    $scope.is_exists_user = (username) ->
      if !$scope.users
        return false
      if username == $rootScope.data.username 
        return true
      tmp_flag = false;
      i = 0
      while i < $scope.users.length
        if $scope.users[i] == username
          tmp_flag = true;
          break;
        i = i + 1
      return tmp_flag

    ### When controller initializes, subscribe to retrieve channels from "control channel" ###
    PubNub.ngSubscribe { channel: $scope.controlChannel }

    ### Register for channel creation message events ###
    $rootScope.$on PubNub.ngMsgEv($scope.controlChannel), (ngEvent, payload) ->
      $scope.$apply -> $scope.channels.push payload.message if $scope.channels.indexOf(payload.message) < 0

    ### Get a reasonable historical backlog of messages to populate the channels list ###
    PubNub.ngHistory { channel: $scope.controlChannel, count:500 }

    ### and finally, create and/or enter the 'WaitingRoom' channel ###
    if $scope.data?.super
      $scope.newChannel = 'WaitingRoom'
      $scope.createChannel()
    else
      $scope.subscribe 'WaitingRoom'

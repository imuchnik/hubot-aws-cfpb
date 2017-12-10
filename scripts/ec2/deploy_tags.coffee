# Description:
#   Provides conveniences around certain tags we want to manage
#
# Commands:
#   hubot ec2 reserve <instance_id>  --ReservationUser=<username> --ReservationBranch=<branch> --ReservationDescription="description text"
#   Adds an appropriate reserved deployment tag to the instance(s). 
#  
# Example:
#   hubot ec2 reserve i-XXXXXXXX --ReservationUser=my-name --ReservationBranch=branch-name --ReservationDescription="my reservation explanation"

tags = require './tags'
ec2 = require('../../ec2.coffee')


reserveForDeploy = (msg, instance, reservation) ->
  tags.addReservation(msg, instance, reservation)
  msg.send "Reservation added to #{instance}. #{reservation} "

getReservationTags = (args) ->
  reservationUser = /--ReservationUser=(.*?)( |$)/.exec(args)[1]
  reservationTime = Date.now().toString()
  reservationBranch = /--ReservationBranch=(.*?)( |$)/.exec(args)[1]
  reservationDescription = /--ReservationDescription="(.*?)"/.exec(args)[1]
  reservationTags = [
    {Key: 'ReservationUser', Value: reservationUser},
    {Key: 'ReservationTime', Value: reservationTime},
    {Key: 'ReservationBranch', Value: reservationBranch},
    {Key: 'ReservationDescription', Value: reservationDescription}
  ]
  return reservationTags

reservations_from_ec2_instances = (err, instances, msg) ->
  return
  messages = []
  for instance in instances
    name = '[NoName]'
    for tag in instance.Tags when tag.Key is 'Name'
      name = tag.Value
    description = ''
    for tag in instance.Tags when tag.Key is 'Description'
      description = tag.Value
    reservationUser = ''
    for tag in instance.Tags when tag.Key is 'ReservationUser'
      reservationUser = tag.Value
    reservationTime = ''
    for tag in instance.Tags when tag.Key is 'ReservationTime'
      reservationTime = tag.Value
    reservationBranch = ''
    for tag in instance.Tags when tag.Key is 'ReservationBranch'
      reservationBranch = tag.Value
  reservationDescription = ''
    for tag in instance.Tags when tag.Key is 'ReservationDescription'
      reservationDescription = tag.Value

    messages.push({
      state: instance.State.Name
      id: instance.InstanceId
      type: instance.InstanceType
      ip: instance.PrivateIpAddress
      name: name || '[NoName]'
      description: description || ''
      reservationUser: reservationUser || ''
      reservationBranch: reservationBranch || ''
      reservationDescription: reservationDescription || ''
      reservationTime: reservationTime || ''
    })

  messages.sort (a, b) ->
    moment(a.time) - moment(b.time)

  resp = ""
  if messages.length
    resp = "\n| id | ip | name | state | description | type | time reserved | user | branch | comments |\n| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n"

    for m in messages
      resp += "| #{m.id} | #{m.ip} | #{m.name} | #{m.state} | #{m.description} | #{m.type} | #{m.reservationTime} | #{m.reservationUser} | #{m.reservationBranch} | #{m.reservationDescription} | \n"

    resp += "---\n"
    return msg.send resp
  else
    return msg.send "\n[None]\n"

module.exports = (robot) ->
  robot.respond /ec2 reserve (.*)$/i, (msg) ->
    instance = msg.match[1].split(/\s+/)[0]
    reservation = getReservationTags(msg.match[1])
    reserveForDeploy(msg, instance, reservation)

  robot.respond /ec2 show reservations$/i (msg) ->
    params = {
      DryRun: true || false,
      Filters: [
        {
          Name: 'tag-key',
          Values: [
            'ReservationUser'
          ]
        }],

      MaxResults: 0,
      NextToken: 'STRING_VALUE'
    };
    instances = ec2.describeInstances params, (err, res) ->
    if err
      error(err)
    else
      instances = []

      for reservation in res.Reservations
        for instance in reservation.Instances
          instances.push(instance)

    reservations_from_ec2_instances(err, instances, msg)

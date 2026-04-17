#!/usr/bin/env -S uv --quiet run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "boto3",
# ]
# ///
# -*- coding: utf-8 -*-
# Author: Chmouel Boudjnah <chmouel@chmouel.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Python script using boto3 to delete route53 zones and records.
#
# You need the credentials setup with whatever means in ~/.aws or via env
# variables.
#
# After the 'reaper' has reaped our openshift install in the aws account, it
# forget to delete some A records, so the reinstall fails :((
# let's be helpful and do it for the reaper....
#

import argparse
import sys

import boto3

DEVCLUSTER_DNS_ZONE = 'devcluster.openshift.com.'


class NoGoZoneIsANogo(Exception):
    pass


def get_hosted_zone_id(client, zonename):
    if not zonename.endswith("."):
        zonename += "."
    resp = client.list_hosted_zones_by_name(DNSName=zonename, MaxItems="1")
    for zone in resp["HostedZones"]:
        if zone["Name"] == zonename:
            return zone["Id"].split("/")[-1]
    return None


def delete_hosted_zone(client, zonename, silent):
    if not zonename.endswith("."):
        zonename += "."
    zone_id = get_hosted_zone_id(client, zonename)
    if not zone_id:
        if not silent:
            print("Could not find " + zonename)
        return

    if not silent:
        print("Deleting zone: " + zonename)

    paginator = client.get_paginator("list_resource_record_sets")
    for page in paginator.paginate(HostedZoneId=zone_id):
        for rec in page["ResourceRecordSets"]:
            if rec["Type"] in ("NS", "SOA"):
                continue
            client.change_resource_record_sets(
                HostedZoneId=zone_id,
                ChangeBatch={
                    "Changes": [
                        {
                            "Action": "DELETE",
                            "ResourceRecordSet": rec,
                        }
                    ]
                },
            )
            if not silent:
                print("\tdeleted record " + rec["Name"])

    client.delete_hosted_zone(Id=zone_id)
    if not silent:
        print("Zone " + zonename + " has been deleted.")


def delete_record(client, zonename, recordname, silent):
    if not zonename.endswith("."):
        zonename += "."
    if not recordname.endswith("."):
        recordname += "."

    zone_id = get_hosted_zone_id(client, zonename)
    if not zone_id:
        raise NoGoZoneIsANogo("Could not find zone for " + zonename)

    try:
        resp = client.list_resource_record_sets(
            HostedZoneId=zone_id,
            StartRecordName=recordname,
            StartRecordType="A",
            MaxItems="1",
        )
    except Exception:
        if not silent:
            print("Could not find record " + recordname)
        return

    record = None
    for rec in resp["ResourceRecordSets"]:
        if rec["Name"] == recordname and rec["Type"] == "A":
            record = rec
            break

    if not record:
        if not silent:
            print("Could not find record " + recordname)
        return

    client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            "Changes": [
                {
                    "Action": "DELETE",
                    "ResourceRecordSet": record,
                }
            ]
        },
    )
    if not silent:
        print("Record " + record["Name"] + " has been deleted.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-f',
                        action='store_true',
                        default=False,
                        dest='force',
                        help='Force install')
    parser.add_argument('-s',
                        action='store_true',
                        default=False,
                        dest='silent',
                        help='Quiet')
    parser.add_argument('-z',
                        dest='dns_zone',
                        default=DEVCLUSTER_DNS_ZONE,
                        help='The devcluster DNS ZONE')
    parser.add_argument('clustername')
    args = parser.parse_args()

    client = boto3.client("route53")

    zonename = args.clustername + '.' + args.dns_zone

    if not args.force:
        if not args.silent:
            print("I am about to delete the zone: " + zonename)
        reply = input(
            "Just out of sanity check, can you please confirm that's what you want [Ny]: "
        )
        if not reply or reply.lower() != 'y':
            sys.exit(0)

    delete_hosted_zone(client, zonename, args.silent)
    delete_record(client, args.dns_zone, "api." + zonename, args.silent)
    delete_record(client, args.dns_zone, "\\052.apps." + zonename, args.silent)

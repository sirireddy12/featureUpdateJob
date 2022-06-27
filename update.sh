#!/bin/bash

export arcFilePath=$1
export releaseName=$2
export fileName=$3
export nameSpace=$4
export updateAction=$5
export features_clusterConnect=$6
export features_customLocations=$7
export features_azureRbac=$8
export features_azureRbac_settings_appId=$9
export features_azureRbac_settings_appSecret=${10}
export features_customLocations_settings_OID=${11}

# removing the prefixs
export arcFilePath=${arcFilePath#"https://"}
export arcFilePath=${arcFilePath#"http://"}

echo "acrPath = $arcFilePath"
echo "releaseName = $releaseName"
echo "fileName = $fileName"
echo "HelmNameSpace = $nameSpace"
echo "updateAction = $updateAction"
echo "features_clusterConnect = $features_clusterConnect"
echo "features_customLocations = $features_customLocations"
echo "features_customLocations_OID = $features_customLocations_OID"
echo "features_azureRbac = $features_azureRbac"
echo "features_azureRbac_settings_appId = $features_azureRbac_settings_appId"
echo "features_azureRbac_settings_appSecret = $features_azureRbac_settings_appSecret"

if [ -f "/usr/local/share/ca-certificates/proxy-cert.crt" ]; then
	echo "Running update-ca-certificates"
	update-ca-certificates
fi


echo "Command: export HELM_EXPERIMENTAL_OCI=1 "
export HELM_EXPERIMENTAL_OCI=1

echo "Command: helm chart pull $arcFilePath"
helm3 chart pull $arcFilePath

if [ $? -ne 0 ]; then
	echo "Failed to pull $arcFilePath"
	exit $?
fi

echo "Command: helm chart export $arcFilePath --destination ."
helm3 chart export $arcFilePath --destination .

if [ $? -ne 0 ]; then
	echo "Failed to export the $arcFilePath"
	exit $?
fi

echo "Command: helm get values $releaseName -n $nameSpace > userValues.txt"
helm3 get values $releaseName -n $nameSpace > userValues.txt

if [ $? -ne 0 ]; then
	echo "Failed to find the releaseName."
	exit $?
fi

# TODO: Remove this part once all users have have upgraded from 0.2.27
isProxyEnabled=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.isProxyEnabled'`
proxyEnabled=false
if [ "$isProxyEnabled" == null ]; then
	httpProxy=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.httpProxy'`
	httpsProxy=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.httpsProxy'`
	noProxy=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.noProxy'`

	if [ "$httpProxy" != null ] || [ "$httpsProxy" != null ] || [ "$noProxy" != null ]; then
		proxyEnabled=true
		export proxyCert=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.proxyCert'`
	fi
else
	if [ "$isProxyEnabled" == "true" ]; then
		proxyEnabled=true
		export proxyCert=`echo $(helm3 get values $releaseName -n $nameSpace  -o json)| jq '.global.proxyCert'`
	fi
fi

#echo "Command: helm upgrade $releaseName $fileName -n $nameSpace -f userValues.txt"

featureArgs=""
if [ "$features_clusterConnect" == "true" ]; then
	echo "Enable cluster connect"
	featureArgs="--set systemDefaultValues.clusterConnect=true"
else
	featureArgs="--set systemDefaultValues.clusterConnect=false"
fi

if [ "$features_customLocations" == "true" ]; then
	echo "Enable custom locations"
	featureArgs="$featureArgs --set systemDefaultValues.customLocations.enabled=true --set systemDefaultValues.customLocations.oid=$features_customLocations_settings_OID"
else
	featureArgs="$featureArgs --set systemDefaultValues.customLocations.enabled=false --set systemDefaultValues.customLocations.oid='' "
fi

if [ "$features_azureRbac" == "true" ]; then
	echo "Enable azure rbac"
	featureArgs="$featureArgs --set systemDefaultValues.gaurd.enabled=true --set systemDefaultValues.gaurd.clientId=$features_azureRbac_settings_appId --set systemDefaultValues.guard.clientSecret=$features_azureRbac_settings_appSecret"
else
	featureArgs="$featureArgs --set systemDefaultValues.gaurd.enabled=false"
fi

echo "Command: helm3 upgrade $releaseName $fileName -n $nameSpace -f userValues.txt --set global.isProxyEnabled=$proxyEnabled $featureArgs --atomic --timeout 25m0s"
helm3 upgrade $releaseName $fileName -n $nameSpace -f userValues.txt --set global.isProxyEnabled=$proxyEnabled $featureArgs --atomic --timeout 25m0s

if [ $? -ne 0 ]; then
	echo "helm upgrade Failed."
	exit $?
fi
@Grab('ch.qos.logback:logback-classic:1.2.1') 
import groovy.json.JsonSlurper

@groovy.util.logging.Slf4j
@CompileStatic
class CommonFunctions {

    private static List readParamsFromJsonSettings(String path) {
        def paramsWithUsage = [:]
        try {
            paramsWithUsage = tryReadParamsFromJsonSettings(path)
        } catch (Exception e) {
            println "Could not read parameters settings from Json. $e"
            paramsWithUsage = Collections.emptyMap()
        }
        return paramsWithUsage
    }

    private static List tryReadParamsFromJsonSettings(String path) throws Exception{
        def paramsContent = new File(path).text
        def paramsWithUsage = new JsonSlurper().parseText(paramsContent)
        paramsWithUsage.get('parameters')
    }

    static Map formatParameterHelpData(param) {
        Map result = [ name: param.name, value: '', usage: param.usage ]
        // value describes the expected input for the param
        result.value = (param.type == boolean.toString()) ? '' : param.choices ?: param.type ?: ''
        return result
    }

    private static String prettyFormatParamGroupWithPaddingAndIndent (List paramGroup,
                                                    String groupName,
                                                    Integer padding=2,
                                                    Integer indent=4) {
            def maxParamNameLength = paramGroup.collect { it.name.size() }.max()
            def paramChoices = paramGroup.findAll{ it.choices }.collect { it.choices }
            def maxChoiceStringLength = paramChoices.collect { it.toString().size()}.max()
            def maxTypeLength = paramGroup.collect { (it.type as String).size() }.max()


            def paramsFormattedList = paramGroup.sort { it.name }.collect {
                    Map param ->
                        def paramHelpData = formatParameterHelpData(param)
                        sprintf("%${indent}s%-${maxParamNameLength + padding}s%-${maxChoiceStringLength + padding}s %s\n", "", "--${paramHelpData.name}","${paramHelpData.value}", "${paramHelpData.usage}")
                }
            String.format("%s:\n%s", groupName.toUpperCase(), paramsFormattedList.join()).stripIndent()
    }

    // choose the indent depending on the spacing in this file
    // in this example there are 4 spaces for every intendation so we choose 4
    private static String prettyFormatParamsWithPaddingAndIndent(List paramsWithUsage, Integer padding=2, Integer indent=4) {
            def groupedParamsWithUsage = paramsWithUsage.groupBy { it.group }
            def formattedParamsGroups = groupedParamsWithUsage.collect {
                prettyFormatParamGroupWithPaddingAndIndent ( it.value, it.key, padding, indent)
            }
            return formattedParamsGroups.join('\n')
    }

    static String helpMessage(paramsWithUsage, workflow) {
        def usageHelp = String.format(
        """\
        Usage:
        The typical command for running the pipeline is as follows:
        nextflow run ${workflow.manifest.name} v${workflow.manifest.version} --reads '*_R{1,2}.fastq.gz' -profile docker
        Options:
        %s
        """.stripIndent(), prettyFormatParamsWithPaddingAndIndent(paramsWithUsage, 2, 4))
    }

    static String createNfcoreHeader(params, workflow) {
        // Log colors ANSI codes
        def c_reset = params.monochrome_logs ? '' : "\033[0m"
        def c_dim = params.monochrome_logs ? '' : "\033[2m"
        def c_black = params.monochrome_logs ? '' : "\033[0;30m"
        def c_green = params.monochrome_logs ? '' : "\033[0;32m"
        def c_yellow = params.monochrome_logs ? '' : "\033[0;33m"
        def c_blue = params.monochrome_logs ? '' : "\033[0;34m"
        def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
        def c_cyan = params.monochrome_logs ? '' : "\033[0;36m"
        def c_white = params.monochrome_logs ? '' : "\033[0;37m"

        def showHeader = String.format(
        """\
        ${c_dim}----------------------------------------------------${c_reset}
                                                ${c_green},--.${c_black}/${c_green},-.${c_reset}
        ${c_blue}        ___     __   __   __   ___     ${c_green}/,-._.--~\'${c_reset}
        ${c_blue}  |\\ | |__  __ /  ` /  \\ |__) |__         ${c_yellow}}  {${c_reset}
        ${c_blue}  | \\| |       \\__, \\__/ |  \\ |___     ${c_green}\\`-._,-`-,${c_reset}
                                                ${c_green}`._,._,\'${c_reset}
        ${c_purple}  ${workflow.manifest.name} v${workflow.manifest.version}${c_reset}
        ${c_dim}----------------------------------------------------${c_reset}
        """.stripIndent())
    }
static inner class ProfileHostNameValidator {
    final Map profileForHosts

    ProfileHostNameValidator(Map profileForHosts) {
        this.profileForHosts = profileForHosts
    }
    
    List findProfilesForHost(String observedHost ) {
        def matchingProfiles = []
        profileForHosts.each { profile, hosts -> 
            if ( hosts.findAll { observedHost.contains(it) } ) {
                matchingProfiles << profile
            }
        }
        return matchingProfiles   
    }
}
    static def checkHostname(params) {
        
        def c_reset = params.monochrome_logs ? '' : "\033[0m"
        def c_white = params.monochrome_logs ? '' : "\033[0;37m"
        def c_red = params.monochrome_logs ? '' : "\033[1;91m"
        def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
        if(params.hostnames){
            def hostname = "hostname".execute().text.trim()
            params.hostnames.each { prof, hnames ->
                hnames.each { hname ->
                    if(hostname.contains(hname) && !workflow.profile.contains(prof)){
                        log.error "====================================================\n" +
                                "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                                "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                                "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                                "============================================================"
                    }
                }
            }
        }
    }

    static void checkAWSbatch(params, workflow) {
        assert !params.awsqueue || !params.awsregion : "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
        // Check outdir paths to be S3 buckets if running on AWSBatch
        // related: https://github.com/nextflow-io/nextflow/issues/813
        assert !params.outdir.startsWith('s3:') : "Outdir not on S3 - specify S3 Bucket to run on AWSBatch!"
        // Prevent trace files to be stored on S3 since S3 does not support rolling files.
        assert workflow.tracedir.startsWith('s3:') :  "Specify a local tracedir or run without trace! S3 cannot be used for tracefiles."
    }

    static String create_workflow_summary(summary, workflow) {

        def yaml_file = workflow.workDir.resolve('workflow_summary_mqc.yaml')
        yaml_file.text  = """
        id: '${workflow.manifest.name}-summary'
        description: " - this information is collected when the pipeline is started."
        section_name: '${workflow.manifest.name} Workflow Summary'
        section_href: '${workflow.manifest.homePage}'
        plot_type: 'html'
        data: |
            <dl clas s =\"dl-horizontal\">
    ${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
            </d l>
        """.stripIndent()
        return yaml_file
    }

    static void workflowReport(summary, workflow, params, baseDir, mqc_report) {
        // Set up the e-mail variables
        def subject = "[$workflow.manifest.name] Successful: $workflow.runName"
        if(!workflow.success){
        subject = "[$workflow.manifest.name] FAILED: $workflow.runName"
        }
        def email_fields = [:]
        email_fields['version'] = workflow.manifest.version
        email_fields['runName'] = workflow.runName
        email_fields['success'] = workflow.success
        email_fields['dateComplete'] = workflow.complete
        email_fields['duration'] = workflow.duration
        email_fields['exitStatus'] = workflow.exitStatus
        email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
        email_fields['errorReport'] = (workflow.errorReport ?: 'None')
        email_fields['commandLine'] = workflow.commandLine
        email_fields['projectDir'] = workflow.projectDir
        email_fields['summary'] = summary
        email_fields['summary']['Date Started'] = workflow.start
        email_fields['summary']['Date Completed'] = workflow.complete
        email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
        email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
        if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
        if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
        if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
        if(workflow.container) email_fields['summary']['Docker image'] = workflow.container
        email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
        email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
        email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

        // Render the TXT template
        def engine = new groovy.text.GStringTemplateEngine()
        def tf = new File("$baseDir/assets/email_template.txt")
        def txt_template = engine.createTemplate(tf).make(email_fields)
        def email_txt = txt_template.toString()

        // Render the HTML template
        def hf = new File("$baseDir/assets/email_template.html")
        def html_template = engine.createTemplate(hf).make(email_fields)
        def email_html = html_template.toString()

        // Render the sendmail template
        def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir", mqcFile: mqc_report, mqcMaxSize: params.maxMultiqcEmailFileSize.toBytes() ]
        def sf = new File("$baseDir/assets/sendmail_template.txt")
        def sendmail_template = engine.createTemplate(sf).make(smail_fields)
        def sendmail_html = sendmail_template.toString()

        // Send the HTML e-mail
        if (params.email) {
            try {
            if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
            // Try to send HTML e-mail using sendmail
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[$workflow.manifest.name] Sent summary e-mail to $params.email (sendmail)"
            } catch (all) {
            // Catch failures and try with plaintext
            [ 'mail', '-s', subject, params.email ].execute() << email_txt
            log.info "[$workflow.manifest.name] Sent summary e-mail to $params.email (mail)"
            }
        }

        // Write summary e-mail HTML to a file
        def output_d = new File( "${params.outdir}/pipeline_info/" )
        if( !output_d.exists() ) {
        output_d.mkdirs()
        }
        def output_hf = new File( output_d, "pipeline_report.html" )
        output_hf.withWriter { w -> w << email_html }
        def output_tf = new File( output_d, "pipeline_report.txt" )
        output_tf.withWriter { w -> w << email_txt }

        def c_reset = params.monochrome_logs ? '' : "\033[0m"
        def c_purple = params.monochrome_logs ? '' : "\033[0;35m"
        def c_green = params.monochrome_logs ? '' : "\033[0;32m"
        def c_red = params.monochrome_logs ? '' : "\033[0;31m"

        if (workflow.stats.ignoredCountFmt > 0 && workflow.success) {
            log.info "${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}"
            log.info "${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCountFmt} ${c_reset}"
            log.info "${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCountFmt} ${c_reset}"
        }

        if(workflow.success){
            log.info "${c_purple}[$workflow.manifest.name]${c_green} Pipeline completed successfully${c_reset}"
        } else {
            checkHostname(params)
            log.info "${c_purple}[$workflow.manifest.name]${c_red} Pipeline completed with errors${c_reset}"
        }
    }
}

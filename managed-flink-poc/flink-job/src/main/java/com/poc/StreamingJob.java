package com.poc;

import com.amazonaws.services.kinesisanalytics.runtime.KinesisAnalyticsRuntime;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.connector.aws.config.AWSConfigConstants;
import org.apache.flink.connector.kinesis.sink.KinesisStreamsSink;
import org.apache.flink.connector.kinesis.source.KinesisStreamsSource;
import org.apache.flink.connector.kinesis.source.config.KinesisStreamsSourceConfigConstants;
import org.apache.flink.connector.kinesis.source.config.KinesisStreamsSourceConfigConstants.InitialPosition;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import java.util.Map;
import java.util.Properties;

/**
 * Sensor Temperature Enrichment
 * 
 * Reads JSON sensor records from an input Kinesis stream, converts the
 * temperature from Celsius to Fahrenheit, mark them as processed, and
 * writes the enriched records to an output Kinesis stream.
 *
 *   input.stream.arn   — ARN of the source Kinesis stream
 *   output.stream.name — name of the destination Kinesis stream
 *   aws.region         — AWS region (e.g. us-east-2)
 */
public class StreamingJob {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static void main(String[] args) throws Exception {

        Map<String, Properties> appProperties =
                KinesisAnalyticsRuntime.getApplicationProperties();

        Properties props = appProperties.getOrDefault(
                "FlinkApplicationProperties", new Properties());

        String inputStreamArn  = props.getProperty("input.stream.arn");
        String outputStreamName = props.getProperty("output.stream.name");
        String region           = props.getProperty("aws.region", "us-east-2");

        if (inputStreamArn == null || outputStreamName == null) {
            throw new IllegalArgumentException(
                    "Missing required properties: input.stream.arn or output.stream.name");
        }

        StreamExecutionEnvironment env =
                StreamExecutionEnvironment.getExecutionEnvironment();

        Configuration sourceConfig = new Configuration();
        sourceConfig.setString(AWSConfigConstants.AWS_REGION, region);
        sourceConfig.set(KinesisStreamsSourceConfigConstants.STREAM_INITIAL_POSITION, InitialPosition.LATEST);

        KinesisStreamsSource<String> source = KinesisStreamsSource.<String>builder()
                .setStreamArn(inputStreamArn)
                .setSourceConfig(sourceConfig)
                .setDeserializationSchema(new SimpleStringSchema())
                .build();

        DataStream<String> rawStream = env.fromSource(
                source,
                WatermarkStrategy.noWatermarks(),
                "Kinesis Input Stream",
                TypeInformation.of(String.class));

        DataStream<String> enriched = rawStream.map(record -> {
            try {
                ObjectNode node = (ObjectNode) MAPPER.readTree(record);

                if (node.has("temperature_c")) {
                    double tempC = node.get("temperature_c").asDouble();
                    double tempF = Math.round((tempC * 9.0 / 5.0 + 32.0) * 100.0) / 100.0;
                    node.put("temperature_f", tempF);
                }

                node.put("processed_by", "flink");
                return MAPPER.writeValueAsString(node);

            } catch (Exception e) {
                // Pass through records that can't be parsed unchanged
                return record;
            }
        }).name("Enrich: C --> F + tag");

        Properties sinkProps = new Properties();
        sinkProps.setProperty("aws.region", region);

        KinesisStreamsSink<String> sink = KinesisStreamsSink.<String>builder()
                .setStreamName(outputStreamName)
                .setKinesisClientProperties(sinkProps)
                .setSerializationSchema(new SimpleStringSchema())
                // Route by hash of the whole record -- spreads load across shards
                .setPartitionKeyGenerator(element -> String.valueOf(element.hashCode()))
                .build();

        enriched.sinkTo(sink);

        env.execute("Sensor Temperature Enrichment");
    }
}

package com.ionicframework.cordova.webview;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;

import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

import android.net.http.SslCertificate;
import android.os.Bundle;
import android.util.Log;


/**
 * Load CA certificates from assets folder and validate against them
 */
public class CertificateInjector
{
    /** The log tag. */
    private static final String               LOG_TAG = CertificateInjector.class.getSimpleName();

    private static final String               X509_CERTIFICATE = "x509-certificate";
    private static final String               X509             = "X.509";
    private static final String               RSA              = "RSA";
    private static final String               DER_EXTENSION    = ".der";

    static private CertificateInjector certificateInjectorInstance      = null;
    private TrustManagerFactory               trustManagerFactoryInstance;

    /**
     * Private constructor
     * Load certificates from assets folder and create a TrustManagerFactory using them
     */
    private CertificateInjector()
    {
        try
        {
            CertificateFactory oCertificateFactory = CertificateFactory.getInstance(X509);
            KeyStore oKeyStore = KeyStore.getInstance(KeyStore.getDefaultType());
            oKeyStore.load(null, null);
            // List and add .der files to KeyStore

            String[] oFilesList = Common.assetManager.list("www/certificates");
            for (String sFileName : oFilesList)
            {
                if (sFileName.endsWith(DER_EXTENSION))
                {
                    InputStream oInputStream = null;
                    try
                    {
                        oInputStream = Common.assetManager.open("www/certificates/"+sFileName);
                        oKeyStore.setCertificateEntry(sFileName, oCertificateFactory.generateCertificate(oInputStream));
                    }
                    catch (CertificateException e)      // Can happen if the certificate is corrupted. It is ignored.
                    {
                        Log.w(LOG_TAG, "Error while parsing the certificate: " + sFileName);
                    }
                    catch (IOException e)
                    {
                        Log.w(LOG_TAG, "Error while loading the certificate: " + sFileName);
                    }
                    finally
                    {
                        if (oInputStream != null)
                        {
                            oInputStream.close();
                        }
                    }
                }
            }
            // Create TrustManagerFactory with the KeyStore
            trustManagerFactoryInstance = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            trustManagerFactoryInstance.init(oKeyStore);
        }
        catch (Exception e)
        {
            e.printStackTrace();
        }
    }

    /**
     * Returns the EmbeddedCertificateTrustManager singleton
     *
     * @return EmbeddedCertificateTrustManager singleton
     */
    public static CertificateInjector getInstance()
    {
        if (certificateInjectorInstance == null)
        {
            certificateInjectorInstance = new CertificateInjector();
        }
        return certificateInjectorInstance;
    }

    /**
     * Checks whether the specified certificate can be validated and is trusted against one of our keystore CA.
     *
     * @param oSslCertificate
     * @throws CertificateException
     */
    public void checkServerTrusted(SslCertificate oSslCertificate) throws CertificateException
    {
        // SslCertificate to x509Certificate
        Bundle oBundle = SslCertificate.saveState(oSslCertificate);
        X509Certificate oX509Certificate;
        byte[] oBytes = oBundle.getByteArray(X509_CERTIFICATE);
        if (oBytes == null)
        {
            oX509Certificate = null;
        }
        else
        {
            try
            {
                CertificateFactory oCertificateFactory = CertificateFactory.getInstance(X509);
                Certificate oCertificate = oCertificateFactory.generateCertificate(new ByteArrayInputStream(oBytes));
                oX509Certificate = (X509Certificate)oCertificate;
            }
            catch (CertificateException e)
            {
                oX509Certificate = null;
            }
        }

        checkServerTrusted(oX509Certificate);
    }

    /**
     * Checks whether the specified certificate can be validated and is trusted against one of our keystore CA.
     *
     * @param oX509Certificate
     * @throws CertificateException
     */
    public void checkServerTrusted(X509Certificate oX509Certificate) throws CertificateException
    {
        X509Certificate[] oChain = new X509Certificate[1];
        oChain[0] = oX509Certificate;
        if (trustManagerFactoryInstance == null)
        {
            throw new CertificateException("Trust Manager Factory is null.");
        }
        for (TrustManager oTrustManager : trustManagerFactoryInstance.getTrustManagers())
        {
            ((X509TrustManager)oTrustManager).checkServerTrusted(oChain, RSA);
        }
    }


    /**
     * Returns the TrustManager Factory, which has been fitted with the embedded Certificates.
     * @return the TrustManager Factory.
     */
    public TrustManagerFactory getTrustManagerFactory() {
        return trustManagerFactoryInstance;
    }
}
